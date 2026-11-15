using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace NetSpeedLite
{
    public class TaskbarController
    {
        [DllImport("user32.dll")]
        private static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

        [DllImport("user32.dll")]
        private static extern IntPtr FindWindowEx(IntPtr hwndParent, IntPtr hwndChildAfter, string lpszClass, string lpszWindow);

        [DllImport("user32.dll")]
        private static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

        [DllImport("user32.dll")]
        private static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

        [DllImport("user32.dll")]
        private static extern bool IsWindowVisible(IntPtr hWnd);

        [StructLayout(LayoutKind.Sequential)]
        public struct RECT
        {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
            public int Width { get { return Right - Left; } }
            public int Height { get { return Bottom - Top; } }
        }

        private static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
        private const uint SWP_NOACTIVATE = 0x0010;
        private const uint SWP_SHOWWINDOW = 0x0040;
        private const uint SWP_NOSIZE = 0x0001;
        private const uint SWP_NOMOVE = 0x0002;

        public const int DefaultWidth = 96;
        public const int DefaultHeight = 32;

        private int _lastX = -1;
        private int _lastY = -1;
        private int _lastWidth = -1;
        private int _lastHeight = -1;

        public void PositionWindow(IntPtr hWnd, int width, int height, bool force = false)
        {
            try
            {
                IntPtr hTray = FindWindow("Shell_TrayWnd", null);
                if (hTray == IntPtr.Zero || !IsWindowVisible(hTray))
                {
                    return;
                }

                RECT trayRect;
                GetWindowRect(hTray, out trayRect);

                IntPtr hNotify = FindWindowEx(hTray, IntPtr.Zero, "TrayNotifyWnd", null);
                int targetX;
                int targetY;

                bool isHorizontal = trayRect.Width >= trayRect.Height;

                if (isHorizontal)
                {
                    if (hNotify != IntPtr.Zero && IsWindowVisible(hNotify))
                    {
                        RECT notifyRect;
                        GetWindowRect(hNotify, out notifyRect);
                        if (notifyRect.Left > trayRect.Left && notifyRect.Left < trayRect.Right)
                        {
                            targetX = notifyRect.Left - width - 6;
                        }
                        else
                        {
                            targetX = trayRect.Right - width - 260;
                        }
                    }
                    else
                    {
                        targetX = trayRect.Right - width - 260;
                    }

                    targetY = trayRect.Top + Math.Max(0, (trayRect.Height - height) / 2);
                }
                else
                {
                    // Vertical taskbar (Win10 left/right)
                    targetX = trayRect.Left + Math.Max(0, (trayRect.Width - width) / 2);
                    if (hNotify != IntPtr.Zero && IsWindowVisible(hNotify))
                    {
                        RECT notifyRect;
                        GetWindowRect(hNotify, out notifyRect);
                        targetY = notifyRect.Top - height - 6;
                    }
                    else
                    {
                        targetY = trayRect.Bottom - height - 200;
                    }
                }

                if (force || targetX != _lastX || targetY != _lastY || width != _lastWidth || height != _lastHeight)
                {
                    _lastX = targetX;
                    _lastY = targetY;
                    _lastWidth = width;
                    _lastHeight = height;
                    SetWindowPos(hWnd, HWND_TOPMOST, targetX, targetY, width, height, SWP_NOACTIVATE | SWP_SHOWWINDOW);
                }
                else
                {
                    // Re-assert topmost Z-order without moving or resizing
                    SetWindowPos(hWnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
                }
            }
            catch {}
        }
    }
}
