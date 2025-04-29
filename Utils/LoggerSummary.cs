// Utils/LoggerSummary.cs
using System.Drawing;
using Spectre.Console;
using System.Threading;
using Color = Spectre.Console.Color;

namespace ForensicTimeliner.Utils;

public static class LoggerSummary
{
    private static readonly Dictionary<(string Artifact, string Tool), int> ToolArtifactSummary = new();

    private static readonly Dictionary<string, string> ArtifactNameMap = new()
    {
        // Axiom
        ["Axiom_ActivityTimeline"] = "Activity Timeline",
        ["Axiom_Amcache"] = "Amcache",
        ["Axiom_AppCompat"] = "AppCompatCache",
        ["Axiom_AutoRuns"] = "Autoruns",
        ["Axiom_EventLogs"] = "EventLogs",
        ["Axiom_LNK"] = "LNK",
        ["Axiom_JumpLists"] = "JumpLists",
        ["Axiom_Shellbags"] = "Shellbags",
        ["Axiom_Registry"] = "Registry",
        ["Axiom_Prefetch"] = "Prefetch",
        ["Axiom_IEHistory"] = "IE History",
        ["Axiom_ChromeHistory"] = "Chrome History",
        ["Axiom_Edge"] = "Edge History",
        ["Axiom_Firefox"] = "Firefox History",
        ["Axiom_Opera"] = "Opera History",
        ["Axiom_RecycleBin"] = "Deleted",
        ["Axiom_MRURecent"] = "MRU - Recent",
        ["Axiom_MRUFolderAccess"] = "MRU - Folder Access",
        ["Axiom_MRUOpenSaved"] = "MRU - Open/Save",
        ["Axiom_UserAssist"] = "UserAssist",


        // Nirsoft
        ["NirsoftBrowsingHistory"] = "Web History",

        // Hayabusa
        ["Hayabusa"] = "Sigma Rules",

        // Chainsaw
        ["Chainsaw_Sigma"] = "Sigma Rules",
        ["Chainsaw_Mft"] = "MFT",
        ["Chainsaw_Persistence"] = "Persistence",
        ["Chainsaw_Powershell"] = "PowerShell",
        ["Chainsaw_ServiceInstallation"] = "Service Installation",
        ["Chainsaw_ServiceTampering"] = "Service Tampering",
        ["Chainsaw_IndicatorRemoval"] = "Indicator Removal",
        ["Chainsaw_LogTampering"] = "Log Tampering",
        ["Chainsaw_CredentialAccess"] = "Credential Access",
        ["Chainsaw_LateralMovement"] = "Lateral Movement",
        ["Chainsaw_DefenseEvasion"] = "Defense Evasion",
        ["Chainsaw_AccountTampering"] = "Account Tampering",
        ["Chainsaw_LoginAttacks"] = "Login Attacks",
        ["Chainsaw_RdpEvents"] = "RDP Events",
        ["Chainsaw_Antivirus"] = "Antivirus",
        ["Chainsaw_AppLocker"] = "AppLocker",
        ["Chainsaw_MicrosoftRDP"] = "Microsoft RDS Events",
        ["Chainsaw_MicrosoftRAS"] = "Microsoft RAS VPN Events",

        // EZ Tools
        ["ActivityTimeline"] = "Activity Timeline",
        ["Amcache"] = "Amcache",
        ["AppCompatCache"] = "AppCompatCache",
        ["EventLogs"] = "EventLogs",
        ["FileDeletion"] = "Deleted",
        ["Jumplists"] = "JumpLists",
        ["LNK"] = "LNK",
        ["MFT"] = "MFT",
        ["Prefetch"] = "Prefetch",
        ["Registry"] = "Registry",
        ["Shellbags"] = "Shellbags",

    };


    public static void TrackSummary(string tool, string artifact, int rowCount)
    {
        string normalizedArtifact = ArtifactNameMap.TryGetValue(artifact, out var mapped) ? mapped : artifact;
        var key = (normalizedArtifact, tool);
        if (!ToolArtifactSummary.ContainsKey(key))
            ToolArtifactSummary[key] = 0;
        ToolArtifactSummary[key] += rowCount;
    }

    public static void PrintFinalSummary()
    {
        if (ToolArtifactSummary.Count == 0)
            return;

        var allTools = ToolArtifactSummary.Keys.Select(k => k.Tool).Distinct().OrderBy(t => t).ToList();
        var allArtifacts = ToolArtifactSummary.Keys.Select(k => k.Artifact).Distinct().OrderBy(a => a).ToList();

        var table = new Table()
            .Title("[bold green]Forensic Timeliner Export Summary[/]")
            .Border(TableBorder.Rounded)
            .BorderColor(Color.Green)
            .AddColumn("[bold]Artifact[/]");

        foreach (var tool in allTools)
            table.AddColumn(new TableColumn(tool).RightAligned());

        foreach (var artifact in allArtifacts)
        {
            var row = new List<string> { artifact };
            foreach (var tool in allTools)
            {
                var count = ToolArtifactSummary.TryGetValue((artifact, tool), out var val) ? val : 0;
                row.Add(count > 0 ? count.ToString() : "-");
            }
            table.AddRow(row.ToArray());
        }

        var totalRow = new List<string> { "[bold yellow]TOTAL[/]" };
        foreach (var tool in allTools)
        {
            var total = ToolArtifactSummary
                .Where(kv => kv.Key.Tool == tool)
                .Sum(kv => kv.Value);
            totalRow.Add(total > 0 ? total.ToString() : "-");
        }
        table.AddRow(totalRow.ToArray());

        // Write the main artifact+tool table
        AnsiConsole.Write(new Padder(table).PadLeft((Console.WindowWidth - 80) / 2));

        // 🛠️ ADD GRAND TOTAL BELOW
        var grandTotal = ToolArtifactSummary.Sum(kv => kv.Value);

        var grandTable = new Table()
            .Border(TableBorder.Rounded)
            .BorderColor(Color.Green)
            .AddColumn(new TableColumn("[bold]Artifact[/]").Centered())
            .AddColumn(new TableColumn("[bold]Count[/]").Centered());

        grandTable.AddRow("[bold]GRAND TOTAL[/]", $"[bold green]{grandTotal}[/]");

        AnsiConsole.WriteLine();
        AnsiConsole.Write(new Padder(grandTable).PadLeft((Console.WindowWidth - 40) / 2));
    }
}
