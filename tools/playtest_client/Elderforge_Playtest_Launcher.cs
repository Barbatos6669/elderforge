using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

internal static class ElderforgePlaytestLauncher
{
	[STAThread]
	private static int Main()
	{
		try
		{
			string appDir = AppDomain.CurrentDomain.BaseDirectory;
			string scriptPath = Path.Combine(appDir, "Elderforge_Playtest_Client.ps1");

			if (!File.Exists(scriptPath))
			{
				MessageBox.Show(
					"Elderforge_Playtest_Client.ps1 was not found next to the launcher.",
					"Elderforge Playtest Launcher",
					MessageBoxButtons.OK,
					MessageBoxIcon.Error);
				return 1;
			}

			ProcessStartInfo startInfo = new ProcessStartInfo();
			startInfo.FileName = "powershell.exe";
			startInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File " + Quote(scriptPath);
			startInfo.WorkingDirectory = appDir;
			startInfo.UseShellExecute = false;
			startInfo.CreateNoWindow = true;

			Process.Start(startInfo);
			return 0;
		}
		catch (Exception ex)
		{
			MessageBox.Show(
				ex.Message,
				"Elderforge Playtest Launcher",
				MessageBoxButtons.OK,
				MessageBoxIcon.Error);
			return 1;
		}
	}

	private static string Quote(string value)
	{
		return "\"" + value.Replace("\"", "\\\"") + "\"";
	}
}
