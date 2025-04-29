// Utils/Banner.cs
using Spectre.Console;

namespace ForensicTimeliner.Utils;

public static class Banner
{
    public static void Print()
    {
        string[] bannerLines = new[]
        {
            "_________________________________________________________________________",
            "|                                                                       |",
            "|                                                                       |",
            "|  ███████╗ ██████╗ ██████╗ ███████╗███╗   ██╗███████╗██╗ ██████╗       |",
            "|  ██╔════╝██╔═══██╗██╔══██╗██╔════╝████╗  ██║██╔════╝██║██╔════╝       |",
            "|  █████╗  ██║   ██║██████╔╝█████╗  ██╔██╗ ██║███████╗██║██║            |",
            "|  ██╔══╝  ██║   ██║██╔══██╗██╔══╝  ██║╚██╗██║╚════██║██║██║            |",
            "|  ██║     ╚██████╔╝██║  ██║███████╗██║ ╚████║███████║██║╚██████╗       |",
            "|  ╚═╝      ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚══════╝╚═╝ ╚═════╝       |",
            "|                                                                       |",
            "|  ████████╗██╗███╗   ███╗███████╗██╗     ██╗███╗   ██╗███████╗██████╗  |",
            "|  ╚══██╔══╝██║████╗ ████║██╔════╝██║     ██║████╗  ██║██╔════╝██╔══██╗ |",
            "|     ██║   ██║██╔████╔██║█████╗  ██║     ██║██╔██╗ ██║█████╗  ██████╔╝ |",
            "|     ██║   ██║██║╚██╔╝██║██╔══╝  ██║     ██║██║╚██╗██║██╔══╝  ██╔══██╗ |",
            "|     ██║   ██║██║ ╚═╝ ██║███████╗███████╗██║██║ ╚████║███████╗██║  ██║ |",
            "|     ╚═╝   ╚═╝╚═╝     ╚═╝╚══════╝╚══════╝╚═╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ |",
            "|                                                                       |",
            "|            by https://github.com/acquiredsecurity                     |",
            "|_______________________________________________________________________|"
        };

        int consoleWidth = Console.WindowWidth;

        for (int i = 0; i < bannerLines.Length; i++)
        {
            string line = bannerLines[i];
            int padding = Math.Max(0, (consoleWidth - line.Length) / 2);
            string paddedLine = new string(' ', padding) + line;

            // Check if this is the GitHub line
            if (line.Contains("https://github.com/acquiredsecurity"))
            {
                AnsiConsole.MarkupLine($"[bold magenta]{paddedLine}[/]");
            }
            else
            {
                AnsiConsole.MarkupLine($"[bold green]{paddedLine}[/]");
            }
        }

        AnsiConsole.WriteLine();
    }
}