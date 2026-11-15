using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Windows.Forms;
using Microsoft.Win32;

namespace NetSpeedLite
{
    public class MainForm : Form
    {
        private const int WM_MOUSEACTIVATE = 0x0021;
        private const int MA_NOACTIVATE = 3;
        private const string RUN_KEY = @"Software\Microsoft\Windows\CurrentVersion\Run";
        private const string APP_NAME = "NetSpeedLite";

        private readonly NetworkMonitor _monitor = new NetworkMonitor();
        private readonly TaskbarController _taskbar = new TaskbarController();
        private readonly Timer _timer = new Timer();
        private readonly ContextMenuStrip _contextMenu = new ContextMenuStrip();
        private ToolStripMenuItem _startWithWindowsItem;

        private Font _font;
        private readonly SolidBrush _cyanBrush = new SolidBrush(Color.FromArgb(56, 189, 248));   // #38BDF8
        private readonly SolidBrush _whiteBrush = new SolidBrush(Color.FromArgb(248, 250, 252)); // #F8FAFC
        private readonly Color _transColor = Color.FromArgb(1, 0, 0);

        private float _arrowWidth = 14f;
        private float _textXOffset = 16f;
        private float _lineHeight = 16f;

        private string _upText = "0.00 KB/s";
        private string _downText = "0.00 KB/s";

        public MainForm()
        {
            this.FormBorderStyle = FormBorderStyle.None;
            this.ShowInTaskbar = false;
            this.StartPosition = FormStartPosition.Manual;
            this.AutoScaleMode = AutoScaleMode.None;
            this.BackColor = _transColor;
            this.TransparencyKey = _transColor;
            this.TopMost = true;

            SetStyle(ControlStyles.AllPaintingInWmPaint |
                     ControlStyles.UserPaint |
                     ControlStyles.OptimizedDoubleBuffer, true);
            UpdateStyles();

            UpdateDpiMetrics();

            BuildContextMenu();
            this.ContextMenuStrip = _contextMenu;

            this.DoubleClick += (s, e) => OpenTaskManager();

            // Initial sampling
            NetworkSpeedSample initialSample = _monitor.GetCurrentSpeed();
            _upText = initialSample.UploadFormatted;
            _downText = initialSample.DownloadFormatted;

            // Timer (1000ms high precision)
            _timer.Interval = 1000;
            _timer.Tick += Timer_Tick;
            _timer.Start();

            // Initial placement
            _taskbar.PositionWindow(this.Handle, this.Width, this.Height, true);
        }

        private void UpdateDpiMetrics()
        {
            using (Graphics g = this.CreateGraphics())
            {
                float dpiScale = g.DpiX / 96.0f;
                if (dpiScale < 1.0f) dpiScale = 1.0f;

                if (_font != null) _font.Dispose();
                _font = new Font("Segoe UI", 8.5f, FontStyle.Regular, GraphicsUnit.Point);

                SizeF arrowTypo = g.MeasureString("↑: ", _font, PointF.Empty, StringFormat.GenericTypographic);
                float xArrow = 2.0f * dpiScale;
                _arrowWidth = arrowTypo.Width;
                _textXOffset = xArrow + _arrowWidth + 3.0f * dpiScale;

                SizeF maxSpeedTypo = g.MeasureString("999.99 MB/s", _font, PointF.Empty, StringFormat.GenericTypographic);
                int neededWidth = (int)Math.Ceiling(_textXOffset + maxSpeedTypo.Width + 6.0f * dpiScale);
                int minWidth = (int)Math.Ceiling(96.0f * dpiScale);
                this.Width = Math.Max(neededWidth, minWidth);

                _lineHeight = _font.GetHeight(g);
                this.Height = (int)Math.Ceiling(_lineHeight * 2.0f + 2.0f * dpiScale);
            }
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

        protected override bool ShowWithoutActivation
        {
            get { return true; }
        }

        protected override void WndProc(ref Message m)
        {
            if (m.Msg == WM_MOUSEACTIVATE)
            {
                m.Result = (IntPtr)MA_NOACTIVATE;
                return;
            }
            base.WndProc(ref m);
        }

        protected override void OnPaintBackground(PaintEventArgs e)
        {
            // Intentionally blank: Prevents background erase flicker completely!
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.HighQuality;
            g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;

            // Atomic clear to transparent color key
            g.Clear(_transColor);

            float dpiScale = g.DpiX / 96.0f;
            if (dpiScale < 1.0f) dpiScale = 1.0f;
            float xArrow = 2.0f * dpiScale;

            float y1 = (this.Height - _lineHeight * 2.0f) / 2.0f;
            if (y1 < 0) y1 = 0;
            float y2 = y1 + _lineHeight;

            // Line 1: Upload (↑: 0.00 KB/s)
            g.DrawString("↑: ", _font, _cyanBrush, xArrow, y1);
            g.DrawString(_upText, _font, _whiteBrush, _textXOffset, y1);

            // Line 2: Download (↓: 0.00 KB/s)
            g.DrawString("↓: ", _font, _cyanBrush, xArrow, y2);
            g.DrawString(_downText, _font, _whiteBrush, _textXOffset, y2);
        }

        private void Timer_Tick(object sender, EventArgs e)
        {
            try
            {
                NetworkSpeedSample sample = _monitor.GetCurrentSpeed();
                _upText = sample.UploadFormatted;
                _downText = sample.DownloadFormatted;

                _taskbar.PositionWindow(this.Handle, this.Width, this.Height);
                this.Invalidate();
            }
            catch {}
        }

        private void BuildContextMenu()
        {
            _contextMenu.Renderer = new DarkMenuRenderer();
            _contextMenu.ShowImageMargin = false;

            ToolStripMenuItem titleItem = new ToolStripMenuItem("  NetSpeedLite v1.0.2") { Enabled = false };
            titleItem.Font = new Font("Segoe UI", 9.0f, FontStyle.Bold);

            ToolStripMenuItem taskMgrItem = new ToolStripMenuItem("  Open Task Manager", null, (s, e) => OpenTaskManager());

            _startWithWindowsItem = new ToolStripMenuItem("  Start with Windows", null, (s, e) => ToggleStartWithWindows());
            _startWithWindowsItem.Checked = IsAutoStartEnabled();

            ToolStripMenuItem exitItem = new ToolStripMenuItem("  Exit", null, (s, e) => {
                _timer.Stop();
                Application.Exit();
            });

            _contextMenu.Items.Add(titleItem);
            _contextMenu.Items.Add(new ToolStripSeparator());
            _contextMenu.Items.Add(taskMgrItem);
            _contextMenu.Items.Add(_startWithWindowsItem);
            _contextMenu.Items.Add(new ToolStripSeparator());
            _contextMenu.Items.Add(exitItem);
        }

        private static void OpenTaskManager()
        {
            try
            {
                Process.Start("taskmgr.exe");
            }
            catch {}
        }

        public static bool IsAutoStartEnabled()
        {
            try
            {
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(RUN_KEY, false))
                {
                    if (key != null)
                    {
                        object val = key.GetValue(APP_NAME);
                        return val != null;
                    }
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
                        if (enable)
                        {
                            key.SetValue(APP_NAME, "\"" + Application.ExecutablePath + "\"");
                        }
                        else
                        {
                            key.DeleteValue(APP_NAME, false);
                        }
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
                if (_timer != null) { _timer.Stop(); _timer.Dispose(); }
                if (_font != null) _font.Dispose();
                if (_cyanBrush != null) _cyanBrush.Dispose();
                if (_whiteBrush != null) _whiteBrush.Dispose();
                if (_contextMenu != null) _contextMenu.Dispose();
            }
            base.Dispose(disposing);
        }
    }
}
