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

        [DllImport("user32.dll")]
        private static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);

        [DllImport("user32.dll")]
        private static extern bool SetThreadDesktop(IntPtr hDesktop);

        [DllImport("user32.dll")]
        private static extern bool CloseDesktop(IntPtr hDesktop);

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

                // Run UI message pump on a clean STA thread attached to the interactive 'Default' desktop
                Thread uiThread = new Thread(() =>
                {
                    IntPtr hDesk = IntPtr.Zero;
                    try
                    {
                        hDesk = OpenDesktop("Default", 0, false, 0x01FF);
                        if (hDesk != IntPtr.Zero)
                        {
                            SetThreadDesktop(hDesk);
                        }
                    }
                    catch {}

                    try
                    {
                        Application.EnableVisualStyles();
                        Application.SetCompatibleTextRenderingDefault(false);
                        Application.Run(new MainForm());
                    }
                    finally
                    {
                        if (hDesk != IntPtr.Zero)
                        {
                            try { CloseDesktop(hDesk); } catch {}
                        }
                    }
                });

                uiThread.SetApartmentState(ApartmentState.STA);
                uiThread.IsBackground = false;
                uiThread.Start();
                uiThread.Join();
            }
        }
    }
}
