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
        private int _sampleCount = 0;

        public long SessionDownloadBytes { get; private set; }
        public long SessionUploadBytes { get; private set; }
        public double PeakDownloadBytesPerSec { get; private set; }
        public double PeakUploadBytesPerSec { get; private set; }
        public string ActiveAdapterName { get; private set; }

        public NetworkMonitor()
        {
            ActiveAdapterName = "No Active Adapter";
            RefreshInterfaces();
            try
            {
                NetworkChange.NetworkAddressChanged += (s, e) => RefreshInterfaces();
                NetworkChange.NetworkAvailabilityChanged += (s, e) => RefreshInterfaces();
            }
            catch {}
        }

        public void ResetSessionStats()
        {
            SessionDownloadBytes = 0;
            SessionUploadBytes = 0;
            PeakDownloadBytesPerSec = 0;
            PeakUploadBytesPerSec = 0;
        }

        public void RefreshInterfaces()
        {
            lock (_cachedInterfaces)
            {
                _cachedInterfaces.Clear();
                string primaryName = null;
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
                            if (primaryName == null)
                            {
                                primaryName = ni.Name + " · " + ni.Description;
                            }
                        }
                    }
                }
                catch {}
                ActiveAdapterName = primaryName ?? "No Active Adapter";
                _isFirstSample = true; // Calibrate next sample to prevent false spike on adapter change
            }
        }

        public NetworkSpeedSample GetCurrentSpeed()
        {
            // Periodically refresh interfaces every 30 samples (30s) in case network changed without OS event
            _sampleCount++;
            if (_sampleCount >= 30)
            {
                _sampleCount = 0;
                RefreshInterfaces();
            }

            long currentIn = 0;
            long currentOut = 0;

            lock (_cachedInterfaces)
            {
                for (int i = 0; i < _cachedInterfaces.Count; i++)
                {
                    try
                    {
                        IPInterfaceStatistics stats = _cachedInterfaces[i].GetIPStatistics();
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
                    DownloadFormatted = "0.0 KB/s",
                    UploadFormatted = "0.0 KB/s"
                };
            }

            double elapsedSeconds = (double)(currentTimestamp - _lastTimestamp) / Stopwatch.Frequency;
            if (elapsedSeconds <= 0.05)
            {
                return new NetworkSpeedSample
                {
                    DownloadBytesPerSec = 0,
                    UploadBytesPerSec = 0,
                    DownloadFormatted = "0.0 KB/s",
                    UploadFormatted = "0.0 KB/s"
                };
            }

            long deltaIn = currentIn >= _lastInBytes ? (currentIn - _lastInBytes) : 0;
            long deltaOut = currentOut >= _lastOutBytes ? (currentOut - _lastOutBytes) : 0;

            double inBps = deltaIn / elapsedSeconds;
            double outBps = deltaOut / elapsedSeconds;

            SessionDownloadBytes += deltaIn;
            SessionUploadBytes += deltaOut;
            if (inBps > PeakDownloadBytesPerSec) PeakDownloadBytesPerSec = inBps;
            if (outBps > PeakUploadBytesPerSec) PeakUploadBytesPerSec = outBps;

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

        public static string FormatSpeed(double bytesPerSec, bool useBits)
        {
            if (useBits)
            {
                double bitsPerSec = bytesPerSec * 8.0;
                if (bitsPerSec < 1000.0 * 1000.0)
                {
                    return string.Format("{0:0.0} Kbps", bitsPerSec / 1000.0);
                }
                else if (bitsPerSec < 1000.0 * 1000.0 * 1000.0)
                {
                    return string.Format("{0:0.00} Mbps", bitsPerSec / (1000.0 * 1000.0));
                }
                else
                {
                    return string.Format("{0:0.00} Gbps", bitsPerSec / (1000.0 * 1000.0 * 1000.0));
                }
            }

            if (bytesPerSec < 1024.0 * 1024.0)
            {
                return string.Format("{0:0.0} KB/s", bytesPerSec / 1024.0);
            }
            else if (bytesPerSec < 1024.0 * 1024.0 * 1024.0)
            {
                return string.Format("{0:0.00} MB/s", bytesPerSec / (1024.0 * 1024.0));
            }
            else
            {
                return string.Format("{0:0.00} GB/s", bytesPerSec / (1024.0 * 1024.0 * 1024.0));
            }
        }

        public static string FormatSpeed(double bytesPerSec)
        {
            return FormatSpeed(bytesPerSec, false);
        }

        public static string FormatBytes(long bytes)
        {
            if (bytes < 1024L * 1024L)
            {
                return string.Format("{0:0.0} KB", bytes / 1024.0);
            }
            else if (bytes < 1024L * 1024L * 1024L)
            {
                return string.Format("{0:0.0} MB", bytes / (1024.0 * 1024.0));
            }
            else
            {
                return string.Format("{0:0.00} GB", bytes / (1024.0 * 1024.0 * 1024.0));
            }
        }
    }
}
