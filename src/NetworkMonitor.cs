using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Net.NetworkInformation;

namespace NetSpeedLite
{
    public class NetworkSpeedSample
    {
        public double DownloadBytesPerSec { get; set; }
        public double UploadBytesPerSec { get; set; }
        public string DownloadFormatted { get; set; }
        public string UploadFormatted { get; set; }
    }

    public class NetworkMonitor
    {
        private readonly List<NetworkInterface> _cachedInterfaces = new List<NetworkInterface>();
        private long _lastInBytes = 0;
        private long _lastOutBytes = 0;
        private long _lastTimestamp = 0;
        private bool _isFirstSample = true;

        public NetworkMonitor()
        {
            RefreshInterfaces();
            try
            {
                NetworkChange.NetworkAddressChanged += (s, e) => RefreshInterfaces();
                NetworkChange.NetworkAvailabilityChanged += (s, e) => RefreshInterfaces();
            }
            catch {}
        }

        public void RefreshInterfaces()
        {
            lock (_cachedInterfaces)
            {
                _cachedInterfaces.Clear();
                try
                {
                    NetworkInterface[] all = NetworkInterface.GetAllNetworkInterfaces();
                    foreach (NetworkInterface ni in all)
                    {
                        if (ni.OperationalStatus == OperationalStatus.Up &&
                            ni.NetworkInterfaceType != NetworkInterfaceType.Loopback &&
                            ni.NetworkInterfaceType != NetworkInterfaceType.Tunnel)
                        {
                            _cachedInterfaces.Add(ni);
                        }
                    }
                }
                catch {}
            }
        }

        public NetworkSpeedSample GetCurrentSpeed()
        {
            long currentIn = 0;
            long currentOut = 0;

            lock (_cachedInterfaces)
            {
                for (int i = 0; i < _cachedInterfaces.Count; i++)
                {
                    try
                    {
                        IPv4InterfaceStatistics stats = _cachedInterfaces[i].GetIPv4Statistics();
                        currentIn += stats.BytesReceived;
                        currentOut += stats.BytesSent;
                    }
                    catch {}
                }
            }

            long currentTimestamp = Stopwatch.GetTimestamp();

            if (_isFirstSample)
            {
                _lastInBytes = currentIn;
                _lastOutBytes = currentOut;
                _lastTimestamp = currentTimestamp;
                _isFirstSample = false;

                return new NetworkSpeedSample
                {
                    DownloadBytesPerSec = 0,
                    UploadBytesPerSec = 0,
                    DownloadFormatted = "0.00 KB/s",
                    UploadFormatted = "0.00 KB/s"
                };
            }

            double elapsedSeconds = (double)(currentTimestamp - _lastTimestamp) / Stopwatch.Frequency;
            if (elapsedSeconds <= 0.05)
            {
                // Sampling too quickly; return zero delta
                return new NetworkSpeedSample
                {
                    DownloadBytesPerSec = 0,
                    UploadBytesPerSec = 0,
                    DownloadFormatted = "0.00 KB/s",
                    UploadFormatted = "0.00 KB/s"
                };
            }

            long deltaIn = currentIn >= _lastInBytes ? (currentIn - _lastInBytes) : 0;
            long deltaOut = currentOut >= _lastOutBytes ? (currentOut - _lastOutBytes) : 0;

            double inBps = deltaIn / elapsedSeconds;
            double outBps = deltaOut / elapsedSeconds;

            _lastInBytes = currentIn;
            _lastOutBytes = currentOut;
            _lastTimestamp = currentTimestamp;

            return new NetworkSpeedSample
            {
                DownloadBytesPerSec = inBps,
                UploadBytesPerSec = outBps,
                DownloadFormatted = FormatSpeed(inBps),
                UploadFormatted = FormatSpeed(outBps)
            };
        }

        public static string FormatSpeed(double bytesPerSec)
        {
            if (bytesPerSec < 1024.0 * 1024.0)
            {
                double kb = bytesPerSec / 1024.0;
                return string.Format("{0:0.00} KB/s", kb);
            }
            else if (bytesPerSec < 1024.0 * 1024.0 * 1024.0)
            {
                double mb = bytesPerSec / (1024.0 * 1024.0);
                return string.Format("{0:0.00} MB/s", mb);
            }
            else
            {
                double gb = bytesPerSec / (1024.0 * 1024.0 * 1024.0);
                return string.Format("{0:0.00} GB/s", gb);
            }
        }
    }
}
