using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace NetSpeedLite
{
    public class DarkMenuRenderer : ToolStripProfessionalRenderer
    {
        private static readonly Color BgColor = Color.FromArgb(22, 25, 34);
        private static readonly Color BorderColor = Color.FromArgb(51, 65, 85);
        private static readonly Color HoverBgColor = Color.FromArgb(42, 49, 66);
        private static readonly Color TextNormal = Color.FromArgb(241, 245, 249);
        private static readonly Color TextDisabled = Color.FromArgb(148, 163, 184);
        private static readonly Color AccentCyan = Color.FromArgb(56, 189, 248);

        public DarkMenuRenderer() : base(new DarkColorTable())
        {
            this.RoundedEdges = true;
        }

        protected override void OnRenderToolStripBackground(ToolStripRenderEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            Rectangle rect = new Rectangle(0, 0, e.ToolStrip.Width, e.ToolStrip.Height);
            using (SolidBrush bg = new SolidBrush(BgColor))
            {
                g.FillRectangle(bg, rect);
            }
        }

        protected override void OnRenderToolStripBorder(ToolStripRenderEventArgs e)
        {
            Rectangle rect = new Rectangle(0, 0, e.ToolStrip.Width - 1, e.ToolStrip.Height - 1);
            using (Pen borderPen = new Pen(BorderColor, 1f))
            {
                e.Graphics.DrawRectangle(borderPen, rect);
            }
        }

        protected override void OnRenderMenuItemBackground(ToolStripItemRenderEventArgs e)
        {
            if (e.Item.Selected && e.Item.Enabled)
            {
                Graphics g = e.Graphics;
                g.SmoothingMode = SmoothingMode.AntiAlias;
                Rectangle rect = new Rectangle(4, 2, e.Item.Width - 8, e.Item.Height - 4);
                using (GraphicsPath path = CreateRoundedRect(rect, 5))
                using (SolidBrush brush = new SolidBrush(HoverBgColor))
                {
                    g.FillPath(brush, path);
                }
            }
        }

        protected override void OnRenderItemText(ToolStripItemTextRenderEventArgs e)
        {
            e.TextColor = e.Item.Enabled ? TextNormal : TextDisabled;
            base.OnRenderItemText(e);
        }

        protected override void OnRenderItemCheck(ToolStripItemImageRenderEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            Rectangle r = e.ImageRectangle;
            int cx = r.Left + r.Width / 2;
            int cy = r.Top + r.Height / 2;

            using (Pen checkPen = new Pen(AccentCyan, 1.8f))
            {
                checkPen.StartCap = LineCap.Round;
                checkPen.EndCap = LineCap.Round;
                checkPen.LineJoin = LineJoin.Round;
                Point[] pts = new Point[]
                {
                    new Point(cx - 4, cy),
                    new Point(cx - 1, cy + 3),
                    new Point(cx + 5, cy - 3)
                };
                g.DrawLines(checkPen, pts);
            }
        }

        protected override void OnRenderSeparator(ToolStripSeparatorRenderEventArgs e)
        {
            int y = e.Item.Height / 2;
            using (Pen sepPen = new Pen(Color.FromArgb(45, 55, 72), 1f))
            {
                e.Graphics.DrawLine(sepPen, 8, y, e.Item.Width - 8, y);
            }
        }

        protected override void OnRenderArrow(ToolStripArrowRenderEventArgs e)
        {
            e.ArrowColor = AccentCyan;
            base.OnRenderArrow(e);
        }

        private static GraphicsPath CreateRoundedRect(Rectangle bounds, int radius)
        {
            int d = radius * 2;
            GraphicsPath path = new GraphicsPath();
            path.AddArc(bounds.X, bounds.Y, d, d, 180, 90);
            path.AddArc(bounds.Right - d, bounds.Y, d, d, 270, 90);
            path.AddArc(bounds.Right - d, bounds.Bottom - d, d, d, 0, 90);
            path.AddArc(bounds.X, bounds.Bottom - d, d, d, 90, 90);
            path.CloseFigure();
            return path;
        }
    }

    public class DarkColorTable : ProfessionalColorTable
    {
        public override Color ToolStripDropDownBackground { get { return Color.FromArgb(22, 25, 34); } }
        public override Color ImageMarginGradientBegin { get { return Color.FromArgb(22, 25, 34); } }
        public override Color ImageMarginGradientMiddle { get { return Color.FromArgb(22, 25, 34); } }
        public override Color ImageMarginGradientEnd { get { return Color.FromArgb(22, 25, 34); } }
        public override Color MenuBorder { get { return Color.FromArgb(51, 65, 85); } }
        public override Color MenuItemBorder { get { return Color.Transparent; } }
        public override Color MenuItemSelected { get { return Color.FromArgb(42, 49, 66); } }
        public override Color MenuItemSelectedGradientBegin { get { return Color.FromArgb(42, 49, 66); } }
        public override Color MenuItemSelectedGradientEnd { get { return Color.FromArgb(42, 49, 66); } }
        public override Color SeparatorDark { get { return Color.FromArgb(45, 55, 72); } }
        public override Color SeparatorLight { get { return Color.Transparent; } }
        public override Color CheckBackground { get { return Color.Transparent; } }
        public override Color CheckSelectedBackground { get { return Color.Transparent; } }
        public override Color CheckPressedBackground { get { return Color.Transparent; } }
    }
}
