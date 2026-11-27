using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using Microsoft.Win32;

namespace NetSpeedLite
{
    public class MainForm : Form
    {
        private const int WM_MOUSEACTIVATE = 0x0021;
        private const int MA_NOACTIVATE = 3;
        private const string RUN_KEY = @"Software\Microsoft\Windows\CurrentVersion\Run";
        private const string PREF_KEY = @"Software\NetSpeedLite";
        private const string APP_NAME = "NetSpeedLite";
        private const int HISTORY_LEN = 16;

        [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)]
        private static extern bool UpdateLayeredWindow(
            IntPtr hwnd, IntPtr hdcDst, IntPtr pptDst, ref SIZE psize,
            IntPtr hdcSrc, ref POINT pptSrc, uint crKey, ref BLENDFUNCTION pblend, uint dwFlags);

        [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)]
        private static extern IntPtr GetDC(IntPtr hWnd);

        [DllImport("user32.dll", ExactSpelling = true)]
        private static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);

        [DllImport("gdi32.dll", ExactSpelling = true, SetLastError = true)]
        private static extern IntPtr CreateCompatibleDC(IntPtr hDC);

        [DllImport("gdi32.dll", ExactSpelling = true, SetLastError = true)]
        private static extern bool DeleteDC(IntPtr hdc);

        [DllImport("gdi32.dll", ExactSpelling = true)]
        private static extern IntPtr SelectObject(IntPtr hDC, IntPtr hObject);

        [DllImport("gdi32.dll", ExactSpelling = true, SetLastError = true)]
        private static extern bool DeleteObject(IntPtr hObject);

        [StructLayout(LayoutKind.Sequential)]
        private struct POINT { public int x; public int y; }

        [StructLayout(LayoutKind.Sequential)]
        private struct SIZE { public int cx; public int cy; }

        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        private struct BLENDFUNCTION
        {
            public byte BlendOp;
            public byte BlendFlags;
            public byte SourceConstantAlpha;
            public byte AlphaFormat;
        }

        private const byte AC_SRC_OVER = 0x00;
        private const byte AC_SRC_ALPHA = 0x01;
        private const uint ULW_ALPHA = 0x00000002;

        private readonly NetworkMonitor _monitor = new NetworkMonitor();
        private readonly TaskbarController _taskbar = new TaskbarController();
        private readonly Timer _timer = new Timer();
        private readonly Timer _hoverTimer = new Timer();
        private readonly ContextMenuStrip _contextMenu = new ContextMenuStrip();

        private FlyoutForm _flyout;

        private ToolStripMenuItem _glassPillItem;
        private ToolStripMenuItem _sparklineItem;
        private ToolStripMenuItem _bitsItem;
        private ToolStripMenuItem _startWithWindowsItem;
        private ToolStripMenuItem[] _themeItems;

        // Preferences
        private bool _glassPill = true;
        private bool _showSparkline = true;
        private bool _useBits = false;
        private int _themeIndex = 0; // 0: Ocean, 1: Cyber Neon, 2: Amber Dusk, 3: Monochrome
        private bool _isLightTaskbar = false;

        // Cached GDI+ resources (zero per-tick allocations)
        private Bitmap _backBuffer;
        private Graphics _gfx;
        private Font _font;
        private float _dpiScale = 1.0f;
        private float _lineHeight = 15f;
        private float _textRightX = 76f;
        private float _sparkX = 83f;
        private float _sparkWidth = 26f;

        private readonly StringFormat _rightAlignFormat = new StringFormat(StringFormat.GenericTypographic)
        {
            FormatFlags = StringFormatFlags.NoWrap,
            Alignment = StringAlignment.Far,
            LineAlignment = StringAlignment.Near
        };

        // Ring buffer for sparkline (zero heap allocations per tick)
        private readonly double[] _downHistory = new double[HISTORY_LEN];
        private readonly double[] _upHistory = new double[HISTORY_LEN];
        private readonly PointF[] _downPts = new PointF[HISTORY_LEN];
        private readonly PointF[] _upPts = new PointF[HISTORY_LEN];
        private int _historyHead = 0;

        private double _lastUpBps = 0;
        private double _lastDownBps = 0;
        private string _upText = "0.0 KB/s";
        private string _downText = "0.0 KB/s";

        public MainForm()
        {
            this.FormBorderStyle = FormBorderStyle.None;
            this.ShowInTaskbar = false;
            this.StartPosition = FormStartPosition.Manual;
            this.AutoScaleMode = AutoScaleMode.None;
            this.TopMost = true;

            LoadPreferences();
            DetectTaskbarTheme();
            SystemEvents.UserPreferenceChanged += OnUserPreferenceChanged;

            UpdateDpiMetrics();
            BuildContextMenu();
            this.ContextMenuStrip = _contextMenu;

            this.DoubleClick += (s, e) => OpenTaskManager();
            this.MouseClick += (s, e) => { if (e.Button == MouseButtons.Middle) ResetStats(); };
            this.MouseEnter += OnWidgetMouseEnter;
            this.MouseLeave += OnWidgetMouseLeave;

            _hoverTimer.Interval = 180;
            _hoverTimer.Tick += HoverTimer_Tick;

            // Initial sampling
            NetworkSpeedSample initialSample = _monitor.GetCurrentSpeed();
            UpdateSampleState(initialSample);

            // Timer (1000ms)
            _timer.Interval = 1000;
            _timer.Tick += Timer_Tick;
            _timer.Start();

            // Initial placement and first render
            _taskbar.PositionWindow(this.Handle, this.Width, this.Height, true);
            RenderLayered();
        }

        protected override CreateParams CreateParams
        {
            get
            {
                CreateParams cp = base.CreateParams;
                cp.Style = unchecked((int)0x94000000); // WS_POPUP | WS_CLIPSIBLINGS | WS_VISIBLE
                cp.ExStyle |= 0x08080088;             // WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW | WS_EX_TOPMOST | WS_EX_LAYERED
                return cp;
            }
        }

        protected override bool ShowWithoutActivation { get { return true; } }

        protected override void WndProc(ref Message m)
        {
            if (m.Msg == WM_MOUSEACTIVATE)
            {
                m.Result = (IntPtr)MA_NOACTIVATE;
                return;
            }
            base.WndProc(ref m);
        }

        protected override void OnPaintBackground(PaintEventArgs e) { }
        protected override void OnPaint(PaintEventArgs e) { }

        private void OnUserPreferenceChanged(object sender, UserPreferenceChangedEventArgs e)
        {
            DetectTaskbarTheme();
            RenderLayered();
            if (_flyout != null && _flyout.Visible) RenderFlyout();
        }

        private void DetectTaskbarTheme()
        {
            try
            {
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(
                    @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", false))
                {
                    if (key != null)
                    {
                        object val = key.GetValue("SystemUsesLightTheme");
                        if (val is int)
                        {
                            _isLightTaskbar = ((int)val) == 1;
                            return;
                        }
                    }
                }
            }
            catch {}
            _isLightTaskbar = false;
        }

        private void GetThemeColors(out Color downAccent, out Color upAccent)
        {
            switch (_themeIndex)
            {
                case 1: // Cyber Neon
                    downAccent = _isLightTaskbar ? Color.FromArgb(219, 39, 119) : Color.FromArgb(244, 114, 182);
                    upAccent = _isLightTaskbar ? Color.FromArgb(8, 145, 178) : Color.FromArgb(34, 211, 238);
                    break;
                case 2: // Amber Dusk
                    downAccent = _isLightTaskbar ? Color.FromArgb(217, 119, 6) : Color.FromArgb(251, 191, 36);
                    upAccent = _isLightTaskbar ? Color.FromArgb(225, 29, 72) : Color.FromArgb(251, 113, 133);
                    break;
                case 3: // Monochrome
                    downAccent = _isLightTaskbar ? Color.FromArgb(30, 41, 59) : Color.FromArgb(248, 250, 252);
                    upAccent = _isLightTaskbar ? Color.FromArgb(100, 116, 139) : Color.FromArgb(148, 163, 184);
                    break;
                case 4: // Aurora
                    downAccent = _isLightTaskbar ? Color.FromArgb(13, 148, 136) : Color.FromArgb(45, 212, 191);
                    upAccent = _isLightTaskbar ? Color.FromArgb(124, 58, 237) : Color.FromArgb(167, 139, 250);
                    break;
                case 5: // Crimson
                    downAccent = _isLightTaskbar ? Color.FromArgb(220, 38, 38) : Color.FromArgb(248, 113, 113);
                    upAccent = _isLightTaskbar ? Color.FromArgb(202, 138, 4) : Color.FromArgb(250, 204, 21);
                    break;
                case 6: // Lavender
                    downAccent = _isLightTaskbar ? Color.FromArgb(79, 70, 229) : Color.FromArgb(129, 140, 248);
                    upAccent = _isLightTaskbar ? Color.FromArgb(192, 38, 211) : Color.FromArgb(232, 121, 249);
                    break;
                case 7: // Matrix
                    downAccent = _isLightTaskbar ? Color.FromArgb(22, 163, 74) : Color.FromArgb(74, 222, 128);
                    upAccent = _isLightTaskbar ? Color.FromArgb(21, 128, 61) : Color.FromArgb(34, 197, 94);
                    break;
                case 8: // Nordic
                    downAccent = _isLightTaskbar ? Color.FromArgb(3, 105, 161) : Color.FromArgb(125, 211, 252);
                    upAccent = _isLightTaskbar ? Color.FromArgb(71, 85, 105) : Color.FromArgb(203, 213, 225);
                    break;
                case 9: // Sunset
                    downAccent = _isLightTaskbar ? Color.FromArgb(234, 88, 12) : Color.FromArgb(251, 146, 60);
                    upAccent = _isLightTaskbar ? Color.FromArgb(225, 29, 72) : Color.FromArgb(244, 63, 94);
                    break;
                default: // 0: Ocean
                    downAccent = _isLightTaskbar ? Color.FromArgb(2, 132, 199) : Color.FromArgb(56, 189, 248);
                    upAccent = _isLightTaskbar ? Color.FromArgb(5, 150, 105) : Color.FromArgb(52, 211, 153);
                    break;
            }
        }

        private void UpdateDpiMetrics()
        {
            using (Graphics g = this.CreateGraphics())
            {
                _dpiScale = g.DpiX / 96.0f;
                if (_dpiScale < 1.0f) _dpiScale = 1.0f;

                if (_font != null) _font.Dispose();
                _font = new Font("Segoe UI Semibold", 8.25f, FontStyle.Regular, GraphicsUnit.Point);

                SizeF maxSpeedTypo = g.MeasureString("999.9 MB/s", _font, PointF.Empty, StringFormat.GenericTypographic);
                _lineHeight = _font.GetHeight(g);

                float padX = 8.0f * _dpiScale;
                float arrowCol = 10.0f * _dpiScale;
                float textWidth = Math.Max(maxSpeedTypo.Width + 3.0f * _dpiScale, 58.0f * _dpiScale);

                _textRightX = padX + arrowCol + textWidth;
                _sparkX = _textRightX + 7.0f * _dpiScale;
                _sparkWidth = 26.0f * _dpiScale;

                float totalW = _showSparkline
                    ? (_sparkX + _sparkWidth + padX)
                    : (_textRightX + padX);

                float lineStep = _lineHeight * 0.90f;
                this.Width = (int)Math.Ceiling(totalW);
                this.Height = (int)Math.Ceiling(lineStep * 2.0f + 6.0f * _dpiScale);
            }

            EnsureBackBuffer();
        }

        private void EnsureBackBuffer()
        {
            if (_backBuffer != null && _backBuffer.Width == this.Width && _backBuffer.Height == this.Height)
            {
                return;
            }

            if (_gfx != null) { _gfx.Dispose(); _gfx = null; }
            if (_backBuffer != null) { _backBuffer.Dispose(); _backBuffer = null; }

            _backBuffer = new Bitmap(Math.Max(1, this.Width), Math.Max(1, this.Height), PixelFormat.Format32bppPArgb);
            _gfx = Graphics.FromImage(_backBuffer);
            _gfx.SmoothingMode = SmoothingMode.AntiAlias;
            _gfx.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            _gfx.PixelOffsetMode = PixelOffsetMode.HighQuality;
        }

        private void OnWidgetMouseEnter(object sender, EventArgs e)
        {
            if (!_contextMenu.Visible)
            {
                _hoverTimer.Start();
            }
        }

        private void OnWidgetMouseLeave(object sender, EventArgs e)
        {
            _hoverTimer.Stop();
            if (_flyout != null && _flyout.Visible)
            {
                _flyout.Hide();
            }
        }

        private void HoverTimer_Tick(object sender, EventArgs e)
        {
            _hoverTimer.Stop();
            if (_contextMenu.Visible) return;
            if (!this.Bounds.Contains(Cursor.Position)) return;

            if (_flyout == null)
            {
                _flyout = new FlyoutForm();
            }

            _flyout.PositionAboveWidget(this.Bounds);
            RenderFlyout();
            if (!_flyout.Visible)
            {
                _flyout.Show();
            }
        }

        private void RenderFlyout()
        {
            if (_flyout == null) return;
            Color downAccent, upAccent;
            GetThemeColors(out downAccent, out upAccent);

            _flyout.Render(
                _isLightTaskbar,
                downAccent,
                upAccent,
                _monitor.ActiveAdapterName,
                _lastDownBps,
                _lastUpBps,
                _monitor.PeakDownloadBytesPerSec,
                _monitor.PeakUploadBytesPerSec,
                _monitor.SessionDownloadBytes,
                _monitor.SessionUploadBytes,
                _useBits,
                _downHistory,
                _upHistory,
                _historyHead);
        }

        private void Timer_Tick(object sender, EventArgs e)
        {
            try
            {
                NetworkSpeedSample sample = _monitor.GetCurrentSpeed();
                UpdateSampleState(sample);

                _taskbar.PositionWindow(this.Handle, this.Width, this.Height);
                RenderLayered();

                if (_flyout != null && _flyout.Visible)
                {
                    RenderFlyout();
                }
            }
            catch {}
        }

        private void UpdateSampleState(NetworkSpeedSample sample)
        {
            _lastUpBps = sample.UploadBytesPerSec;
            _lastDownBps = sample.DownloadBytesPerSec;
            _upText = NetworkMonitor.FormatSpeed(_lastUpBps, _useBits);
            _downText = NetworkMonitor.FormatSpeed(_lastDownBps, _useBits);

            _downHistory[_historyHead] = _lastDownBps;
            _upHistory[_historyHead] = _lastUpBps;
            _historyHead = (_historyHead + 1) % HISTORY_LEN;
        }

        private void RenderLayered()
        {
            if (this.IsDisposed || !this.IsHandleCreated) return;
            EnsureBackBuffer();

            Graphics g = _gfx;
            int w = _backBuffer.Width;
            int h = _backBuffer.Height;

            g.Clear(Color.Transparent);

            if (_glassPill)
            {
                DrawGlassPill(g, w, h);
            }
            else
            {
                using (SolidBrush hitBrush = new SolidBrush(Color.FromArgb(1, 0, 0, 0)))
                {
                    g.FillRectangle(hitBrush, 0, 0, w, h);
                }
            }

            float padX = 8.0f * _dpiScale;
            float lineStep = _lineHeight * 0.90f;
            float y1 = (h - (lineStep + _lineHeight)) / 2.0f;
            if (y1 < 1f) y1 = 1f;
            float y2 = y1 + lineStep;

            bool upActive = _lastUpBps >= 1024.0;
            bool downActive = _lastDownBps >= 1024.0;
            bool upHigh = _lastUpBps >= 1024.0 * 1024.0;
            bool downHigh = _lastDownBps >= 1024.0 * 1024.0;

            Color downAccent, upAccent;
            GetThemeColors(out downAccent, out upAccent);

            Color upArrowColor = Color.FromArgb(upActive ? 250 : 155, upAccent);
            Color downArrowColor = Color.FromArgb(downActive ? 250 : 155, downAccent);

            Color upTextColor = GetSpeedTextColor(upActive, upHigh);
            Color downTextColor = GetSpeedTextColor(downActive, downHigh);

            float arrowCenterX = padX + 3.5f * _dpiScale;
            DrawVectorArrow(g, arrowCenterX, y1 + _lineHeight * 0.52f, true, upArrowColor);
            DrawVectorArrow(g, arrowCenterX, y2 + _lineHeight * 0.52f, false, downArrowColor);

            if (!_glassPill)
            {
                Color shadowColor = _isLightTaskbar
                    ? Color.FromArgb(75, 255, 255, 255)
                    : Color.FromArgb(145, 0, 0, 0);
                using (SolidBrush shadowBrush = new SolidBrush(shadowColor))
                {
                    g.DrawString(_upText, _font, shadowBrush, _textRightX + 0.8f, y1 + 0.8f, _rightAlignFormat);
                    g.DrawString(_downText, _font, shadowBrush, _textRightX + 0.8f, y2 + 0.8f, _rightAlignFormat);
                }
            }

            using (SolidBrush upBrush = new SolidBrush(upTextColor))
            using (SolidBrush downBrush = new SolidBrush(downTextColor))
            {
                g.DrawString(_upText, _font, upBrush, _textRightX, y1, _rightAlignFormat);
                g.DrawString(_downText, _font, downBrush, _textRightX, y2, _rightAlignFormat);
            }

            if (_showSparkline)
            {
                DrawSparkline(g, _sparkX, 5.5f * _dpiScale, _sparkWidth, h - 11.0f * _dpiScale, downAccent, upAccent);
            }

            CommitLayeredBitmap(_backBuffer);
        }

        private Color GetSpeedTextColor(bool active, bool high)
        {
            if (_isLightTaskbar)
            {
                if (high) return Color.FromArgb(255, 15, 23, 42);
                if (active) return Color.FromArgb(235, 30, 41, 59);
                return Color.FromArgb(175, 51, 65, 85);
            }
            else
            {
                if (high) return Color.FromArgb(255, 255, 255, 255);
                if (active) return Color.FromArgb(245, 241, 245, 249);
                return Color.FromArgb(175, 203, 213, 225);
            }
        }

        private void DrawGlassPill(Graphics g, int w, int h)
        {
            RectangleF pillRect = new RectangleF(0f, 0f, w, h);
            float radius = 8.0f * _dpiScale;

            using (GraphicsPath path = CreateRoundedRect(pillRect, radius))
            {
                Color fill = _isLightTaskbar
                    ? Color.FromArgb(40, 255, 255, 255)
                    : Color.FromArgb(14, 255, 255, 255);

                using (SolidBrush bgBrush = new SolidBrush(fill))
                {
                    g.FillPath(bgBrush, path);
                }
            }
        }

        private void DrawVectorArrow(Graphics g, float cx, float cy, bool up, Color color)
        {
            float halfH = 3.2f * _dpiScale;
            float headW = 2.5f * _dpiScale;
            float headH = 2.2f * _dpiScale;

            using (Pen pen = new Pen(color, 1.35f * _dpiScale))
            {
                pen.StartCap = LineCap.Round;
                pen.EndCap = LineCap.Round;
                pen.LineJoin = LineJoin.Round;

                g.DrawLine(pen, cx, cy - halfH, cx, cy + halfH);

                if (up)
                {
                    g.DrawLine(pen, cx - headW, cy - halfH + headH, cx, cy - halfH);
                    g.DrawLine(pen, cx + headW, cy - halfH + headH, cx, cy - halfH);
                }
                else
                {
                    g.DrawLine(pen, cx - headW, cy + halfH - headH, cx, cy + halfH);
                    g.DrawLine(pen, cx + headW, cy + halfH - headH, cx, cy + halfH);
                }
            }
        }

        private void DrawSparkline(Graphics g, float x, float y, float w, float h, Color downAccent, Color upAccent)
        {
            if (h <= 4f || w <= 4f) return;

            double maxVal = 65536.0;
            bool hasTraffic = false;
            for (int i = 0; i < HISTORY_LEN; i++)
            {
                if (_downHistory[i] >= 512.0 || _upHistory[i] >= 512.0) hasTraffic = true;
                if (_downHistory[i] > maxVal) maxVal = _downHistory[i];
                if (_upHistory[i] > maxVal) maxVal = _upHistory[i];
            }

            if (!hasTraffic) return;

            float stepX = w / (HISTORY_LEN - 1);
            float bottomY = y + h;

            for (int i = 0; i < HISTORY_LEN; i++)
            {
                int idx = (_historyHead + i) % HISTORY_LEN;
                float px = x + i * stepX;

                float downRatio = (float)(_downHistory[idx] / maxVal);
                float upRatio = (float)(_upHistory[idx] / maxVal);

                _downPts[i] = new PointF(px, bottomY - downRatio * h);
                _upPts[i] = new PointF(px, bottomY - upRatio * h);
            }

            Color downTop = Color.FromArgb(75, downAccent.R, downAccent.G, downAccent.B);
            Color downBot = Color.FromArgb(4, downAccent.R, downAccent.G, downAccent.B);

            RectangleF sparkBounds = new RectangleF(x, y, w, Math.Max(2f, h));
            using (LinearGradientBrush areaBrush = new LinearGradientBrush(
                sparkBounds, downTop, downBot, LinearGradientMode.Vertical))
            using (GraphicsPath fillPath = new GraphicsPath())
            using (Pen downPen = new Pen(Color.FromArgb(230, downAccent), 1.2f * _dpiScale))
            using (Pen upPen = new Pen(Color.FromArgb(195, upAccent), 1.0f * _dpiScale))
            {
                downPen.LineJoin = LineJoin.Round;
                upPen.LineJoin = LineJoin.Round;

                fillPath.AddCurve(_downPts, 0, HISTORY_LEN - 1, 0.3f);
                fillPath.AddLine(x + w, bottomY, x, bottomY);
                fillPath.CloseFigure();

                g.FillPath(areaBrush, fillPath);
                g.DrawCurve(upPen, _upPts, 0, HISTORY_LEN - 1, 0.3f);
                g.DrawCurve(downPen, _downPts, 0, HISTORY_LEN - 1, 0.3f);
            }
        }

        private void CommitLayeredBitmap(Bitmap bitmap)
        {
            IntPtr screenDc = GetDC(IntPtr.Zero);
            IntPtr memDc = CreateCompatibleDC(screenDc);
            IntPtr hBitmap = IntPtr.Zero;
            IntPtr oldBitmap = IntPtr.Zero;

            try
            {
                hBitmap = bitmap.GetHbitmap(Color.FromArgb(0));
                oldBitmap = SelectObject(memDc, hBitmap);

                SIZE size = new SIZE { cx = bitmap.Width, cy = bitmap.Height };
                POINT pointSource = new POINT { x = 0, y = 0 };
                BLENDFUNCTION blend = new BLENDFUNCTION
                {
                    BlendOp = AC_SRC_OVER,
                    BlendFlags = 0,
                    SourceConstantAlpha = 255,
                    AlphaFormat = AC_SRC_ALPHA
                };

                UpdateLayeredWindow(this.Handle, screenDc, IntPtr.Zero, ref size, memDc, ref pointSource, 0, ref blend, ULW_ALPHA);
            }
            finally
            {
                if (oldBitmap != IntPtr.Zero) SelectObject(memDc, oldBitmap);
                if (hBitmap != IntPtr.Zero) DeleteObject(hBitmap);
                DeleteDC(memDc);
                ReleaseDC(IntPtr.Zero, screenDc);
            }
        }

        private static GraphicsPath CreateRoundedRect(RectangleF bounds, float radius)
        {
            float d = radius * 2.0f;
            GraphicsPath path = new GraphicsPath();
            path.AddArc(bounds.X, bounds.Y, d, d, 180, 90);
            path.AddArc(bounds.Right - d, bounds.Y, d, d, 270, 90);
            path.AddArc(bounds.Right - d, bounds.Bottom - d, d, d, 0, 90);
            path.AddArc(bounds.X, bounds.Bottom - d, d, d, 90, 90);
            path.CloseFigure();
            return path;
        }

        private void BuildContextMenu()
        {
            _contextMenu.Renderer = new DarkMenuRenderer();
            _contextMenu.ShowImageMargin = true;
            _contextMenu.Opening += (s, e) => {
                _hoverTimer.Stop();
                if (_flyout != null && _flyout.Visible) _flyout.Hide();
            };

            ToolStripMenuItem titleItem = new ToolStripMenuItem("NetSpeedLite v1.1.0") { Enabled = false };
            titleItem.Font = new Font("Segoe UI", 9.0f, FontStyle.Bold);

            _glassPillItem = new ToolStripMenuItem("Glass Pill", null, (s, e) => ToggleGlassPill());
            _glassPillItem.Checked = _glassPill;

            _sparklineItem = new ToolStripMenuItem("Mini Sparkline", null, (s, e) => ToggleSparkline());
            _sparklineItem.Checked = _showSparkline;

            _bitsItem = new ToolStripMenuItem("Show in Bits (Mbps)", null, (s, e) => ToggleBits());
            _bitsItem.Checked = _useBits;

            ToolStripMenuItem themeMenu = new ToolStripMenuItem("Theme");
            string[] themeNames = new string[]
            {
                "Ocean (Default)",
                "Cyber Neon",
                "Amber Dusk",
                "Monochrome",
                "Aurora",
                "Crimson",
                "Lavender",
                "Matrix",
                "Nordic",
                "Sunset"
            };
            _themeItems = new ToolStripMenuItem[themeNames.Length];
            for (int i = 0; i < themeNames.Length; i++)
            {
                int idx = i;
                _themeItems[i] = new ToolStripMenuItem(themeNames[i], null, (s, e) => SelectTheme(idx));
                _themeItems[i].Checked = (_themeIndex == i);
                themeMenu.DropDownItems.Add(_themeItems[i]);
            }

            ToolStripMenuItem resetItem = new ToolStripMenuItem("Reset Session Stats", null, (s, e) => ResetStats());
            ToolStripMenuItem taskMgrItem = new ToolStripMenuItem("Open Task Manager", null, (s, e) => OpenTaskManager());

            _startWithWindowsItem = new ToolStripMenuItem("Start with Windows", null, (s, e) => ToggleStartWithWindows());
            _startWithWindowsItem.Checked = IsAutoStartEnabled();

            ToolStripMenuItem exitItem = new ToolStripMenuItem("Exit", null, (s, e) => {
                _timer.Stop();
                Application.Exit();
            });

            _contextMenu.Items.Add(titleItem);
            _contextMenu.Items.Add(new ToolStripSeparator());
            _contextMenu.Items.Add(_glassPillItem);
            _contextMenu.Items.Add(_sparklineItem);
            _contextMenu.Items.Add(_bitsItem);
            _contextMenu.Items.Add(themeMenu);
            _contextMenu.Items.Add(new ToolStripSeparator());
            _contextMenu.Items.Add(resetItem);
            _contextMenu.Items.Add(taskMgrItem);
            _contextMenu.Items.Add(_startWithWindowsItem);
            _contextMenu.Items.Add(new ToolStripSeparator());
            _contextMenu.Items.Add(exitItem);
        }

        private void SelectTheme(int idx)
        {
            _themeIndex = idx;
            for (int i = 0; i < _themeItems.Length; i++)
            {
                _themeItems[i].Checked = (i == idx);
            }
            SavePreferences();
            RenderLayered();
        }

        private void ResetStats()
        {
            _monitor.ResetSessionStats();
            if (_flyout != null && _flyout.Visible) RenderFlyout();
        }

        private void ToggleGlassPill()
        {
            _glassPill = !_glassPill;
            _glassPillItem.Checked = _glassPill;
            SavePreferences();
            RenderLayered();
        }

        private void ToggleSparkline()
        {
            _showSparkline = !_showSparkline;
            _sparklineItem.Checked = _showSparkline;
            SavePreferences();
            UpdateDpiMetrics();
            _taskbar.PositionWindow(this.Handle, this.Width, this.Height, true);
            RenderLayered();
        }

        private void ToggleBits()
        {
            _useBits = !_useBits;
            _bitsItem.Checked = _useBits;
            SavePreferences();
            _upText = NetworkMonitor.FormatSpeed(_lastUpBps, _useBits);
            _downText = NetworkMonitor.FormatSpeed(_lastDownBps, _useBits);
            RenderLayered();
        }

        private void LoadPreferences()
        {
            try
            {
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(PREF_KEY, false))
                {
                    if (key != null)
                    {
                        object pill = key.GetValue("GlassPill");
                        if (pill is int) _glassPill = ((int)pill) != 0;

                        object spark = key.GetValue("ShowSparkline");
                        if (spark is int) _showSparkline = ((int)spark) != 0;

                        object bits = key.GetValue("UseBits");
                        if (bits is int) _useBits = ((int)bits) != 0;

                        object theme = key.GetValue("Theme");
                        if (theme is int)
                        {
                            int t = (int)theme;
                            if (t >= 0 && t <= 9) _themeIndex = t;
                        }
                    }
                }
            }
            catch {}
        }

        private void SavePreferences()
        {
            try
            {
                using (RegistryKey key = Registry.CurrentUser.CreateSubKey(PREF_KEY))
                {
                    if (key != null)
                    {
                        key.SetValue("GlassPill", _glassPill ? 1 : 0, RegistryValueKind.DWord);
                        key.SetValue("ShowSparkline", _showSparkline ? 1 : 0, RegistryValueKind.DWord);
                        key.SetValue("UseBits", _useBits ? 1 : 0, RegistryValueKind.DWord);
                        key.SetValue("Theme", _themeIndex, RegistryValueKind.DWord);
                    }
                }
            }
            catch {}
        }

        private static void OpenTaskManager()
        {
            try { Process.Start("taskmgr.exe"); } catch {}
        }

        public static bool IsAutoStartEnabled()
        {
            try
            {
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(RUN_KEY, false))
                {
                    if (key != null) return key.GetValue(APP_NAME) != null;
                }
            }
            catch {}
            return false;
        }

        public static void SetAutoStart(bool enable)
        {
            try
            {
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(RUN_KEY, true))
                {
                    if (key != null)
                    {
                        if (enable) key.SetValue(APP_NAME, "\"" + Application.ExecutablePath + "\"");
                        else key.DeleteValue(APP_NAME, false);
                    }
                }
            }
            catch {}
        }

        private void ToggleStartWithWindows()
        {
            bool nextState = !IsAutoStartEnabled();
            SetAutoStart(nextState);
            _startWithWindowsItem.Checked = nextState;
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                try { SystemEvents.UserPreferenceChanged -= OnUserPreferenceChanged; } catch {}
                if (_hoverTimer != null) { _hoverTimer.Stop(); _hoverTimer.Dispose(); }
                if (_timer != null) { _timer.Stop(); _timer.Dispose(); }
                if (_flyout != null) { _flyout.Dispose(); _flyout = null; }
                if (_gfx != null) { _gfx.Dispose(); _gfx = null; }
                if (_backBuffer != null) { _backBuffer.Dispose(); _backBuffer = null; }
                if (_font != null) _font.Dispose();
                if (_rightAlignFormat != null) _rightAlignFormat.Dispose();
                if (_contextMenu != null) _contextMenu.Dispose();
            }
            base.Dispose(disposing);
        }
    }
}
