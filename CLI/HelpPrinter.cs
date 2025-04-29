using Spectre.Console;

namespace ForensicTimeliner.CLI;

public static class HelpPrinter
{
    public static void Show()
    {
        // Banner (styled text + styled panel)
        var bannerText = new Text("Forensic Timeliner Help\nBuilds a timeline from forensic CSV exports",
            new Style(foreground: Color.Green, decoration: Decoration.Bold));

        var banner = new Panel(bannerText)
        {
            Border = BoxBorder.Rounded,
            BorderStyle = new Style(Color.Fuchsia),
            Padding = new Padding(1, 1)
        };

        AnsiConsole.Write(Align.Center(banner));
        AnsiConsole.WriteLine();

        // Parameter Table (safe styling with markup)
        var paramTable = new Table()
            .Centered()
            .Title("Command Line Parameters")
            .AddColumn("Argument")      
            .AddColumn("Description");

        paramTable.AddRow(
            new Markup("[white bold]--BaseDir[/]"),
            new Markup("[green]Root directory for forensic CSV files (default: C:\\triage)[/]"));

        paramTable.AddRow(
            new Markup("[white bold]--OutputFile[/]"),
            new Markup("[green]Timeline output file path (default: timestamped CSV)[/]"));

        paramTable.AddRow(
            new Markup("[white bold]--StartDate[/]"),
            new Markup("[green]Filter start datetime (YYYY-MM-DD or ISO)[/]"));

        paramTable.AddRow(
            new Markup("[white bold]--EndDate[/]"),
            new Markup("[green]Filter end datetime (YYYY-MM-DD or ISO)[/]"));

        paramTable.AddRow(
            new Markup("[white bold]--Deduplicate[/]"),
            new Markup("[green]Enable deduplication of timeline rows[/]"));

        paramTable.AddRow(
            new Markup("[white bold]--IncludeRawData[/]"),
            new Markup("[green]Add flattened RawData field to each timeline row[/]"));

        paramTable.AddRow(
            new Markup("[white bold]--ExportFormat[/]"),
            new Markup("[green]Choose output format (csv or json)[/]"));

        paramTable.AddRow(
            new Markup("[white bold]--Interactive[/]"),
            new Markup("[green]Launch the interactive menu[/]"));

        paramTable.AddRow(
            new Markup("[white bold]--NoBanner[/]"),
            new Markup("[green]Suppress the banner header[/]"));

        paramTable.AddRow(
            new Markup("[white bold]--Help[/]"),
            new Markup("[green]Show this help menu[/]"));

        AnsiConsole.Write(paramTable);
        AnsiConsole.WriteLine();


        // Tool Switches Table
        var toolTable = new Table()
            .Centered()
            .Title("Tool Toggles")
            .AddColumn("Switch")       // plain header
            .AddColumn("Description");  // plain header
         

        toolTable.AddRow(
            new Markup("[white bold]--ProcessEZ[/]"),
            new Markup("[green]Enable EZ Tools / KAPE parsing[/]"));

        toolTable.AddRow(
            new Markup("[white bold]--ProcessChainsaw[/]"),
            new Markup("[green]Enable Chainsaw Sigma rule parsing[/]"));

        toolTable.AddRow(
            new Markup("[white bold]--ProcessHayabusa[/]"),
            new Markup("[green]Enable Hayabusa event log parsing[/]"));

        toolTable.AddRow(
            new Markup("[white bold]--ProcessNirsoft[/]"),
            new Markup("[green]Enable Nirsoft WebHistoryView parsing[/]"));

        toolTable.AddRow(
            new Markup("[white bold]--ALL[/]"),
            new Markup("[green]Enable all artifact types (except Axiom)[/]"));

        AnsiConsole.Write(toolTable);
        AnsiConsole.WriteLine();

        // Usage Examples (safe with colored Text)
        var exampleText = new Text(string.Join('\n', new[]
        {
            "Examples:",
            "forensic-timeliner.exe --Interactive",
            "forensic-timeliner.exe --ProcessEZ --Deduplicate --StartDate 1997-01-01",
            "forensic-timeliner.exe --ALL --Preview --BaseDir C:\\triage --OutputFile C:\\triage\\timeline.csv",
            "forensic-timeliner.exe --ALL --IncludeRawData --ExportFormat json --BaseDir C:\\triage"
        }), new Style(Color.Blue));

        var examplePanel = new Panel(exampleText)
        {
            Border = BoxBorder.Double,
            BorderStyle = new Style(Color.MediumPurple),
            Padding = new Padding(1, 1),
            Header = new PanelHeader("Usage Examples", Justify.Center)
        };

        AnsiConsole.Write(Align.Center(examplePanel));
        AnsiConsole.WriteLine();

        // Footer
        var footerText = new Text("Tip: Use --Interactive or -i to configure modules with prompts", new Style(Color.Grey, decoration: Decoration.Italic));

        var footerPanel = new Panel(footerText)
        {
            Border = BoxBorder.Rounded,
            BorderStyle = new Style(Color.Grey),
            Padding = new Padding(1, 1)
        };

        AnsiConsole.Write(Align.Center(footerPanel));
        AnsiConsole.WriteLine();
    }
}
