// Utils/Logger.cs
using System.Text;
using Spectre.Console;

namespace ForensicTimeliner.Utils;

public static class Logger
{
    private static readonly string LogFilePath = Path.Combine(
        Path.GetDirectoryName(Environment.ProcessPath)!,
        "forensic_timeliner.log");

    public static void PrintBanner()
    {
        Console.WriteLine("Forensic Timeliner (C#)");
        Console.WriteLine("=======================");
    }

    public static void LogSuccess(string message)
    {
        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine(message);
        Console.ResetColor();
        WriteToFile("SUCCESS", message);
    }

    public static void LogScan(string message)
    {
        Console.ForegroundColor = ConsoleColor.Blue;
        Console.WriteLine(message);
        Console.ResetColor();
        WriteToFile("SCAN", message);
    }

    public static void LogError(string message)
    {
        Console.ForegroundColor = ConsoleColor.Red;
        Console.WriteLine(message);
        Console.ResetColor();
        WriteToFile("ERROR", message);
    }

    public static void LogWarning(string message)
    {
        Console.ForegroundColor = ConsoleColor.DarkYellow;
        Console.WriteLine(message);
        Console.ResetColor();
        WriteToFile("WARN", message);
    }

    public static void LogWarn(string message)
    {
        AnsiConsole.MarkupLine($"[yellow][!] {message}[/]");
    }
    public static void LogInfo(string message)
    {
        Console.WriteLine(message);
        WriteToFile("INFO", message);
    }

    public static void PrintAndLog(string message, string level = "INFO")
    {
        switch (level.ToUpper())
        {
            case "ERROR":
                LogError(message);
                break;
            case "WARN":
                LogWarning(message);
                break;
            case "SUCCESS":
                LogSuccess(message);
                break;
            case "SCAN":
                LogScan(message);
                break;
            default:
                LogInfo(message);
                break;
        }
    }

    private static void WriteToFile(string level, string message)
    {
        var logMessage = $"[{DateTime.UtcNow:yyyy-MM-dd HH:mm:ss}] [{level}] {message}";
        try
        {
            File.AppendAllText(LogFilePath, logMessage + Environment.NewLine, Encoding.UTF8);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[!] Failed to write to log: {ex.Message}");
        }
    }
}
