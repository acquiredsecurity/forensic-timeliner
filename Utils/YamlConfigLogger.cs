// Utils/YamlConfigLogger.cs
using Spectre.Console;
using System.Collections.Generic;
using System.Linq;
using System.Threading;

namespace ForensicTimeliner.Utils;

public static class YamlConfigLogger
{
    public static void PrintLoadedConfigs(
        List<(string Tool, string Artifact, string Path, bool Enabled)> configs,
        bool skipVisual = false
    )
    {
        if (skipVisual || configs.Count == 0)
            return;

        AnsiConsole.Write(new Rule("[bold lime]Artifact Yaml Configs Loaded[/]").Centered());

        // Define custom tool display order
        var toolOrder = new List<string>
        {
            "Axiom",
            "Chainsaw",
            "Hayabusa",
            "Nirsoft",
            "EZTools"
        };

        // Group configs by Tool
        var groupedConfigs = configs
            .GroupBy(c => c.Tool)
            .OrderBy(g => toolOrder.IndexOf(g.Key) >= 0 ? toolOrder.IndexOf(g.Key) : int.MaxValue)
            .ThenBy(g => g.Key)
            .ToList();

        var tables = new List<Table>();

        foreach (var group in groupedConfigs)
        {
            var table = new Table()
                .Border(TableBorder.Rounded)
                .Title($"[bold cyan]{group.Key}[/]")
                .AddColumn(new TableColumn("[bold]Artifact[/]").NoWrap())
                .AddColumn(new TableColumn("[bold]Path[/]"))
                .AddColumn(new TableColumn("[bold]Enabled[/]").NoWrap());

            foreach (var (tool, artifact, path, enabled) in group)
            {
                string enabledStatus = enabled ? "[green]Yes[/]" : "[red]No[/]";
                table.AddRow(
                    $"[white]{artifact}[/]",
                    $"[gray]{path}[/]",
                    enabledStatus
                );
            }

            tables.Add(table);
        }

        // Layout the tables in Columns
        AnsiConsole.Write(new Columns(tables)
            .PadRight(3)
            .PadLeft(3)
            .Collapse());

        // Show countdown with Spacebar skip
        AnsiConsole.MarkupLine("\n[grey]Pausing for [bold yellow]10[/] seconds... (Press [bold yellow]Spacebar[/] to skip)[/]\n");

        int countdown = 10;

        while (countdown > 0)
        {
            if (Console.KeyAvailable)
            {
                var key = Console.ReadKey(intercept: true);
                if (key.Key == ConsoleKey.Spacebar)
                {
                    AnsiConsole.MarkupLine("[green]Countdown skipped by user.[/]\n");
                    break;
                }
            }

            AnsiConsole.Markup($"[grey]Continuing in[/] [bold yellow]{countdown}[/]...\r");
            Thread.Sleep(1000);
            countdown--;
        }

        if (countdown == 0)
        {
            AnsiConsole.MarkupLine("[green]Countdown complete. Continuing...[/]\n");
        }
    }
}
