using System.Drawing;
using System.Windows.Forms;

namespace NetSpeedLite
{
    public class DarkMenuRenderer : ToolStripProfessionalRenderer
    {
        public DarkMenuRenderer() : base(new DarkColorTable()) { }

        protected override void OnRenderItemText(ToolStripItemTextRenderEventArgs e)
        {
            if (e.Item.Enabled)
                e.TextColor = Color.FromArgb(241, 245, 249);
            else
                e.TextColor = Color.FromArgb(148, 163, 184);
            base.OnRenderItemText(e);
        }

        protected override void OnRenderArrow(ToolStripArrowRenderEventArgs e)
        {
            e.ArrowColor = Color.FromArgb(56, 189, 248);
            base.OnRenderArrow(e);
        }
    }

    public class DarkColorTable : ProfessionalColorTable
    {
        public override Color ToolStripDropDownBackground { get { return Color.FromArgb(24, 27, 36); } }
        public override Color ImageMarginGradientBegin { get { return Color.FromArgb(24, 27, 36); } }
        public override Color ImageMarginGradientMiddle { get { return Color.FromArgb(24, 27, 36); } }
        public override Color ImageMarginGradientEnd { get { return Color.FromArgb(24, 27, 36); } }
        public override Color MenuBorder { get { return Color.FromArgb(51, 65, 85); } }
        public override Color MenuItemBorder { get { return Color.Transparent; } }
        public override Color MenuItemSelected { get { return Color.FromArgb(39, 45, 62); } }
        public override Color MenuItemSelectedGradientBegin { get { return Color.FromArgb(39, 45, 62); } }
        public override Color MenuItemSelectedGradientEnd { get { return Color.FromArgb(39, 45, 62); } }
        public override Color SeparatorDark { get { return Color.FromArgb(51, 65, 85); } }
        public override Color SeparatorLight { get { return Color.Transparent; } }
        public override Color CheckBackground { get { return Color.FromArgb(39, 45, 62); } }
        public override Color CheckSelectedBackground { get { return Color.FromArgb(56, 189, 248); } }
        public override Color CheckPressedBackground { get { return Color.FromArgb(56, 189, 248); } }
    }
}
