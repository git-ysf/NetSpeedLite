using System;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace NetSpeedLite
{
    static class Program
    {
        [DllImport("user32.dll")]
        private static extern bool SetProcessDPIAware();

        [STAThread]
        static void Main()
        {
            try
            {
                SetProcessDPIAware();
            }
            catch {}

            bool createdNew;
            using (Mutex mutex = new Mutex(true, "NetSpeedLite_SingleInstance_Mutex_Global", out createdNew))
            {
                if (!createdNew)
                {
                    return; // Already running
                }

                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.Run(new MainForm());
            }
        }
    }
}
