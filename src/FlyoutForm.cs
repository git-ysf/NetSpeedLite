using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace NetSpeedLite
{
    public class FlyoutForm : Form
    {
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

        private Bitmap _backBuffer;
        private Graphics _gfx;
        private float _dpiScale = 1.0f;

        private Font _titleFont;
        private Font _labelFont;
        private Font _valueFont;
        private Font _subFont;

        private readonly StringFormat _ellipsisFormat = new StringFormat(StringFormat.GenericTypographic)
        {
            FormatFlags = StringFormatFlags.NoWrap,
            Trimming = StringTrimming.EllipsisCharacter
        };

        private readonly StringFormat _rightFormat = new StringFormat(StringFormat.GenericTypographic)
        {
            FormatFlags = StringFormatFlags.NoWrap,
            Alignment = StringAlignment.Far
        };

        public FlyoutForm()
        {
            this.FormBorderStyle = FormBorderStyle.None;
            this.ShowInTaskbar = false;
            this.StartPosition = FormStartPosition.Manual;
            this.AutoScaleMode = AutoScaleMode.None;
            this.TopMost = true;

            UpdateMetrics();
        }

        protected override CreateParams CreateParams
        {
            get
            {
                CreateParams cp = base.CreateParams;
                cp.Style = unchecked((int)0x84000000); // WS_POPUP | WS_CLIPSIBLINGS
                cp.ExStyle |= 0x08080088;             // WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW | WS_EX_TOPMOST | WS_EX_LAYERED
                return cp;
            }
        }

        protected override bool ShowWithoutActivation { get { return true; } }

        private void UpdateMetrics()
        {
            using (Graphics g = this.CreateGraphics())
            {
                _dpiScale = g.DpiX / 96.0f;
                if (_dpiScale < 1.0f) _dpiScale = 1.0f;
            }

            if (_titleFont != null) _titleFont.Dispose();
            if (_labelFont != null) _labelFont.Dispose();
            if (_valueFont != null) _valueFont.Dispose();
            if (_subFont != null) _subFont.Dispose();

            _titleFont = new Font("Segoe UI Semibold", 8.5f, FontStyle.Regular, GraphicsUnit.Point);
            _labelFont = new Font("Segoe UI", 7.5f, FontStyle.Regular, GraphicsUnit.Point);
            _valueFont = new Font("Segoe UI Semibold", 10.5f, FontStyle.Regular, GraphicsUnit.Point);
            _subFont = new Font("Segoe UI", 7.5f, FontStyle.Regular, GraphicsUnit.Point);

            this.Width = (int)Math.Ceiling(282.0f * _dpiScale);
            this.Height = (int)Math.Ceiling(136.0f * _dpiScale);

            if (_gfx != null) { _gfx.Dispose(); _gfx = null; }
            if (_backBuffer != null) { _backBuffer.Dispose(); _backBuffer = null; }

            _backBuffer = new Bitmap(this.Width, this.Height, PixelFormat.Format32bppPArgb);
            _gfx = Graphics.FromImage(_backBuffer);
            _gfx.SmoothingMode = SmoothingMode.AntiAlias;
            _gfx.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            _gfx.PixelOffsetMode = PixelOffsetMode.HighQuality;
        }

        public void PositionAboveWidget(Rectangle widgetBounds)
        {
            Screen scr = Screen.FromRectangle(widgetBounds);
            Rectangle wa = scr.WorkingArea;

            int gap = (int)(8.0f * _dpiScale);
            int x = widgetBounds.Right - this.Width;
            int y = widgetBounds.Top - this.Height - gap;

            if (x < wa.Left + 8) x = wa.Left + 8;
            if (x + this.Width > wa.Right - 8) x = wa.Right - this.Width - 8;
            if (y < wa.Top + 8) y = widgetBounds.Bottom + gap;

            this.Location = new Point(x, y);
        }

        public void Render(
            bool isLight,
            Color downAccent,
            Color upAccent,
            string adapterName,
            double downBps,
            double upBps,
            double peakDownBps,
            double peakUpBps,
            long sessionDownBytes,
            long sessionUpBytes,
            bool useBits,
            double[] downHistory,
            double[] upHistory,
            int historyHead)
        {
            if (this.IsDisposed || !this.IsHandleCreated) return;

            Graphics g = _gfx;
            int w = _backBuffer.Width;
            int h = _backBuffer.Height;
            float s = _dpiScale;

            g.Clear(Color.Transparent);

            // Outer translucent glass card (borderless soft edge)
            RectangleF cardRect = new RectangleF(1f, 1f, w - 2.0f, h - 2.0f);
            float radius = 11.0f * s;
            using (GraphicsPath cardPath = CreateRoundedRect(cardRect, radius))
            {
                Color topFill = isLight
                    ? Color.FromArgb(255, 255, 255, 255)
                    : Color.FromArgb(255, 22, 27, 38);
                Color botFill = isLight
                    ? Color.FromArgb(255, 241, 245, 249)
                    : Color.FromArgb(255, 14, 18, 28);

                using (LinearGradientBrush bg = new LinearGradientBrush(cardRect, topFill, botFill, LinearGradientMode.Vertical))
                {
                    bg.WrapMode = WrapMode.TileFlipXY;
                    g.FillPath(bg, cardPath);
                }

                Color border = isLight
                    ? Color.FromArgb(255, 203, 213, 225)
                    : Color.FromArgb(255, 42, 50, 68);
                using (Pen borderPen = new Pen(border, 1.0f))
                {
                    g.DrawPath(borderPen, cardPath);
                }
            }

            float pad = 13.0f * s;
            Color primaryTxt = isLight ? Color.FromArgb(245, 15, 23, 42) : Color.FromArgb(248, 248, 250, 252);
            Color mutedTxt = isLight ? Color.FromArgb(180, 71, 85, 105) : Color.FromArgb(175, 148, 163, 184);
            Color dividerCol = isLight ? Color.FromArgb(24, 15, 23, 42) : Color.FromArgb(26, 255, 255, 255);

            // Header: live status dot + adapter name
            float dotSize = 6.5f * s;
            float headerY = 11.0f * s;
            using (SolidBrush dotBrush = new SolidBrush(Color.FromArgb(245, 52, 211, 153)))
            {
                g.FillEllipse(dotBrush, pad, headerY + 4.0f * s, dotSize, dotSize);
            }
            RectangleF titleRect = new RectangleF(pad + dotSize + 6.0f * s, headerY, w - (pad * 2 + dotSize + 6.0f * s), 16.0f * s);
            using (SolidBrush titleBrush = new SolidBrush(primaryTxt))
            {
                g.DrawString(adapterName, _titleFont, titleBrush, titleRect, _ellipsisFormat);
            }

            // Subtle divider
            float divY = 32.0f * s;
            using (Pen divPen = new Pen(dividerCol, 1.0f))
            {
                g.DrawLine(divPen, pad, divY, w - pad, divY);
            }

            // Two-column metrics: Download (left) | Upload (right)
            float col1X = pad;
            float col2X = w * 0.52f;
            float rowLabelY = 39.0f * s;
            float rowValY = 51.0f * s;
            float rowSubY = 70.0f * s;

            using (SolidBrush downBrush = new SolidBrush(downAccent))
            using (SolidBrush upBrush = new SolidBrush(upAccent))
            using (SolidBrush valBrush = new SolidBrush(primaryTxt))
            using (SolidBrush subBrush = new SolidBrush(mutedTxt))
            {
                g.DrawString("DOWNLOAD", _labelFont, downBrush, col1X, rowLabelY);
                g.DrawString("UPLOAD", _labelFont, upBrush, col2X, rowLabelY);

                g.DrawString(NetworkMonitor.FormatSpeed(downBps, useBits), _valueFont, valBrush, col1X, rowValY);
                g.DrawString(NetworkMonitor.FormatSpeed(upBps, useBits), _valueFont, valBrush, col2X, rowValY);

                string downSub = string.Format("Peak {0} · {1}",
                    NetworkMonitor.FormatSpeed(peakDownBps, useBits),
                    NetworkMonitor.FormatBytes(sessionDownBytes));
                string upSub = string.Format("Peak {0} · {1}",
                    NetworkMonitor.FormatSpeed(peakUpBps, useBits),
                    NetworkMonitor.FormatBytes(sessionUpBytes));

                g.DrawString(downSub, _subFont, subBrush, new RectangleF(col1X, rowSubY, col2X - col1X - 4f * s, 14f * s), _ellipsisFormat);
                g.DrawString(upSub, _subFont, subBrush, new RectangleF(col2X, rowSubY, w - col2X - pad, 14f * s), _ellipsisFormat);
            }

            // Bottom sparkline box
            float gx = pad;
            float gy = 90.0f * s;
            float gw = w - pad * 2.0f;
            float gh = h - gy - 12.0f * s;
            DrawFlyoutSparkline(g, gx, gy, gw, gh, isLight, downAccent, upAccent, downHistory, upHistory, historyHead);

            CommitLayeredBitmap(_backBuffer);
        }

        private void DrawFlyoutSparkline(
            Graphics g, float x, float y, float w, float h,
            bool isLight, Color downAccent, Color upAccent,
            double[] downHistory, double[] upHistory, int historyHead)
        {
            int len = downHistory.Length;
            if (len < 2 || w <= 4f || h <= 4f) return;

            // Subtle inset background
            RectangleF boxRect = new RectangleF(x, y, w, h);
            using (GraphicsPath boxPath = CreateRoundedRect(boxRect, 5.0f * _dpiScale))
            {
                Color boxBg = isLight
                    ? Color.FromArgb(255, 232, 238, 246)
                    : Color.FromArgb(255, 10, 13, 20);
                using (SolidBrush b = new SolidBrush(boxBg))
                {
                    g.FillPath(b, boxPath);
                }
            }

            double maxVal = 65536.0;
            for (int i = 0; i < len; i++)
            {
                if (downHistory[i] > maxVal) maxVal = downHistory[i];
                if (upHistory[i] > maxVal) maxVal = upHistory[i];
            }

            float innerPad = 3.0f * _dpiScale;
            float ix = x + innerPad;
            float iw = w - innerPad * 2f;
            float iy = y + innerPad;
            float ih = h - innerPad * 2f;
            float bottomY = iy + ih;
            float stepX = iw / (len - 1);

            PointF[] dnPts = new PointF[len];
            PointF[] upPts = new PointF[len];
            for (int i = 0; i < len; i++)
            {
                int idx = (historyHead + i) % len;
                float px = ix + i * stepX;
                dnPts[i] = new PointF(px, bottomY - (float)(downHistory[idx] / maxVal) * ih);
                upPts[i] = new PointF(px, bottomY - (float)(upHistory[idx] / maxVal) * ih);
            }

            Color downTop = Color.FromArgb(75, downAccent.R, downAccent.G, downAccent.B);
            Color downBot = Color.FromArgb(4, downAccent.R, downAccent.G, downAccent.B);

            using (LinearGradientBrush areaBrush = new LinearGradientBrush(
                new RectangleF(ix, iy, iw, Math.Max(2f, ih)), downTop, downBot, LinearGradientMode.Vertical))
            using (GraphicsPath fillPath = new GraphicsPath())
            using (Pen downPen = new Pen(Color.FromArgb(230, downAccent), 1.4f * _dpiScale))
            using (Pen upPen = new Pen(Color.FromArgb(195, upAccent), 1.15f * _dpiScale))
            {
                downPen.LineJoin = LineJoin.Round;
                upPen.LineJoin = LineJoin.Round;

                fillPath.AddCurve(dnPts, 0, len - 1, 0.3f);
                fillPath.AddLine(ix + iw, bottomY, ix, bottomY);
                fillPath.CloseFigure();

                g.FillPath(areaBrush, fillPath);
                g.DrawCurve(upPen, upPts, 0, len - 1, 0.3f);
                g.DrawCurve(downPen, dnPts, 0, len - 1, 0.3f);
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

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                if (_gfx != null) { _gfx.Dispose(); _gfx = null; }
                if (_backBuffer != null) { _backBuffer.Dispose(); _backBuffer = null; }
                if (_titleFont != null) _titleFont.Dispose();
                if (_labelFont != null) _labelFont.Dispose();
                if (_valueFont != null) _valueFont.Dispose();
                if (_subFont != null) _subFont.Dispose();
                if (_ellipsisFormat != null) _ellipsisFormat.Dispose();
                if (_rightFormat != null) _rightFormat.Dispose();
            }
            base.Dispose(disposing);
        }
    }
}
