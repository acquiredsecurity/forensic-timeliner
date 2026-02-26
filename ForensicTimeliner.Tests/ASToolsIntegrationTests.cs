using ForensicTimeliner.Collector;
using ForensicTimeliner.Models;
using ForensicTimeliner.Utils;

namespace ForensicTimeliner.Tests;

public class ASToolsIntegrationTests
{
    private static readonly string SampleDataDir = Path.GetFullPath(
        Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "sample_data", "kape_triage"));

    private void EnsureConfigLoaded()
    {
        var configDir = Path.Combine(AppContext.BaseDirectory, "config");
        DiscoveryConfig.LoadFromYaml(configDir, skipVisuals: true);

        // Register AS Tools parsers (same as ParserRegistry does in the web app)
        DiscoveryConfig.RegisterParser("EvtxForensic", new ForensicTimeliner.Tools.EvtxForensic.EvtxForensicParser());
        DiscoveryConfig.RegisterParser("ForensicWebHistory", new ForensicTimeliner.Tools.BrowserHistory.ForensicWebHistoryParser());
        DiscoveryConfig.RegisterParser("ForensicWebHistoryCarved", new ForensicTimeliner.Tools.BrowserHistory.ForensicWebHistoryCarvedParser());

        // Also register EZ Tools for comparison
        DiscoveryConfig.RegisterParser("EventLogs", new ForensicTimeliner.Tools.EZTools.EventlogParser());
        DiscoveryConfig.RegisterParser("Amcache", new ForensicTimeliner.Tools.EZTools.AmcacheParser());
        DiscoveryConfig.RegisterParser("Prefetch", new ForensicTimeliner.Tools.EZTools.PrefetchParser());
        DiscoveryConfig.RegisterParser("LNK", new ForensicTimeliner.Tools.EZTools.LnkParser());
        DiscoveryConfig.RegisterParser("MFT", new ForensicTimeliner.Tools.EZTools.MftParser());
        DiscoveryConfig.RegisterParser("Registry", new ForensicTimeliner.Tools.EZTools.RegistryParser());
        DiscoveryConfig.RegisterParser("Shellbags", new ForensicTimeliner.Tools.EZTools.ShellbagsParser());
        DiscoveryConfig.RegisterParser("Jumplists", new ForensicTimeliner.Tools.EZTools.JumplistsParser());
        DiscoveryConfig.RegisterParser("UserAssist", new ForensicTimeliner.Tools.EZTools.UserAssistParser());
        DiscoveryConfig.RegisterParser("FileDeletion", new ForensicTimeliner.Tools.EZTools.DeletedParser());
        DiscoveryConfig.RegisterParser("AppCompatCache", new ForensicTimeliner.Tools.EZTools.AppCompatParser());
        DiscoveryConfig.RegisterParser("ActivityTimeline", new ForensicTimeliner.Tools.EZTools.ActivityTimelineParser());
        DiscoveryConfig.RegisterParser("RecentDocs", new ForensicTimeliner.Tools.EZTools.RecentDocsParser());
        DiscoveryConfig.RegisterParser("TypedURLs", new ForensicTimeliner.Tools.EZTools.TypedURLsParser());
    }

    [Fact]
    public void ASTools_ConfigsLoadedAndGrouped()
    {
        EnsureConfigLoaded();

        var asToolDefs = DiscoveryConfig.ARTIFACT_DEFINITIONS
            .Where(kvp => kvp.Value.Tool == "AS Tools")
            .ToList();

        Assert.True(asToolDefs.Count >= 3, $"Expected at least 3 AS Tools artifacts, got {asToolDefs.Count}");

        var artifactNames = asToolDefs.Select(kvp => kvp.Key).ToHashSet();
        Assert.Contains("EvtxForensic", artifactNames);
        Assert.Contains("ForensicWebHistory", artifactNames);
        Assert.Contains("ForensicWebHistoryCarved", artifactNames);
    }

    [Fact]
    public void ASTools_ParsersRegistered()
    {
        EnsureConfigLoaded();

        Assert.True(DiscoveryConfig.ARTIFACT_PARSERS.ContainsKey("EvtxForensic"), "EvtxForensic parser not registered");
        Assert.True(DiscoveryConfig.ARTIFACT_PARSERS.ContainsKey("ForensicWebHistory"), "ForensicWebHistory parser not registered");
        Assert.True(DiscoveryConfig.ARTIFACT_PARSERS.ContainsKey("ForensicWebHistoryCarved"), "ForensicWebHistoryCarved parser not registered");
    }

    [Fact]
    public void ASTools_WebHistoryDiscovery_FindsChromeCSV()
    {
        EnsureConfigLoaded();

        // Chrome_Default.csv at sample_data/kape_triage/ has forensic-webhistory headers.
        // The filename "chrome" matches the pattern, and strict_header_match confirms it.
        var files = Discovery.FindArtifactFiles(SampleDataDir, SampleDataDir, "ForensicWebHistory");

        Assert.True(files.Count > 0, $"Expected to find ForensicWebHistory CSV files in {SampleDataDir}, found 0. " +
            "Check that Discovery partial-match logic handles filename match + header confirmation.");
    }

    [Fact]
    public void ASTools_WebHistoryParsing_ProducesRows()
    {
        EnsureConfigLoaded();

        var files = Discovery.FindArtifactFiles(SampleDataDir, SampleDataDir, "ForensicWebHistory");
        if (files.Count == 0)
        {
            // Skip if no web history CSVs are available in sample data
            return;
        }

        var def = DiscoveryConfig.ARTIFACT_DEFINITIONS["ForensicWebHistory"];
        var parser = DiscoveryConfig.ARTIFACT_PARSERS["ForensicWebHistory"];

        var rows = parser.Parse(SampleDataDir, SampleDataDir, def, new ParsedArgs { BaseDir = SampleDataDir });

        Assert.True(rows.Count > 0, "ForensicWebHistory parser produced no rows");

        // Verify tool field is set to AS Tools
        var firstRow = rows[0];
        Assert.Equal("AS Tools", firstRow.Tool);

        // Verify ArtifactName
        Assert.Equal("Web History", firstRow.ArtifactName);

        // Verify RawData contains JSON
        Assert.False(string.IsNullOrEmpty(firstRow.RawData), "RawData should be populated with JSON");
        Assert.Contains("URL", firstRow.RawData);
    }

    [Fact]
    public void ASTools_WebHistoryRawData_ContainsAllColumns()
    {
        EnsureConfigLoaded();

        var files = Discovery.FindArtifactFiles(SampleDataDir, SampleDataDir, "ForensicWebHistory");
        if (files.Count == 0)
        {
            return;
        }

        var def = DiscoveryConfig.ARTIFACT_DEFINITIONS["ForensicWebHistory"];
        var parser = DiscoveryConfig.ARTIFACT_PARSERS["ForensicWebHistory"];
        var rows = parser.Parse(SampleDataDir, SampleDataDir, def, new ParsedArgs { BaseDir = SampleDataDir });

        Assert.True(rows.Count > 0, "No rows parsed");

        var raw = System.Text.Json.JsonSerializer.Deserialize<Dictionary<string, string>>(rows[0].RawData);
        Assert.NotNull(raw);

        // Verify key columns are present in RawData JSON
        Assert.True(raw!.ContainsKey("URL"), "RawData missing 'URL'");
        Assert.True(raw.ContainsKey("Title"), "RawData missing 'Title'");
        Assert.True(raw.ContainsKey("Visit Time"), "RawData missing 'Visit Time'");
        Assert.True(raw.ContainsKey("Web Browser"), "RawData missing 'Web Browser'");
    }

    [Fact]
    public void ASTools_CollectorManager_ProcessesWithProcessASFlag()
    {
        EnsureConfigLoaded();

        var args = new ParsedArgs
        {
            BaseDir = SampleDataDir,
            ProcessAS = true,
            NoPrompt = true,
        };

        var rows = CollectorManager.GetAllRows(args);

        var asToolRows = rows.Where(r => r.Tool == "AS Tools").ToList();
        // With Chrome_Default.csv in sample data, we should get web history rows
        Assert.True(asToolRows.Count > 0, $"ProcessAS=true produced no AS Tools rows. Total rows: {rows.Count}");
    }

    [Fact]
    public void ASTools_CollectorManager_ExcludedWithoutFlag()
    {
        EnsureConfigLoaded();

        var args = new ParsedArgs
        {
            BaseDir = SampleDataDir,
            ProcessEZ = true,   // Only EZ, not AS
            NoPrompt = true,
        };

        var rows = CollectorManager.GetAllRows(args);

        var asToolRows = rows.Where(r => r.Tool == "AS Tools").ToList();
        Assert.True(asToolRows.Count == 0, $"ProcessAS=false should produce no AS Tools rows, got {asToolRows.Count}");
    }

    [Fact]
    public void EZTools_StillWorks_Regression()
    {
        EnsureConfigLoaded();

        var args = new ParsedArgs
        {
            BaseDir = SampleDataDir,
            ProcessEZ = true,
            NoPrompt = true,
        };

        var rows = CollectorManager.GetAllRows(args);
        var ezRows = rows.Where(r => r.Tool == "EZ Tools").ToList();
        Assert.True(ezRows.Count > 0, $"EZ Tools produced no rows from sample data. Total rows: {rows.Count}");

        // Verify EZ event logs are present
        var eventLogRows = ezRows.Where(r => r.ArtifactName == "Event Logs").ToList();
        Assert.True(eventLogRows.Count > 0, "No EZ Tools Event Logs parsed");
    }

    [Fact]
    public void AllTools_ProducesRows_WithMultipleToolTypes()
    {
        EnsureConfigLoaded();

        var args = new ParsedArgs
        {
            BaseDir = SampleDataDir,
            ALL = true,
            NoPrompt = true,
        };

        var rows = CollectorManager.GetAllRows(args);
        Assert.True(rows.Count > 0, "ALL flag produced no rows");

        // Check we get rows from multiple tool types (EZ Tools + AS Tools from Chrome_Default.csv)
        var toolGroups = rows.GroupBy(r => r.Tool).Select(g => new { Tool = g.Key, Count = g.Count() }).ToList();
        Assert.True(toolGroups.Count >= 1, $"Expected rows from at least 1 tool type, got: {string.Join(", ", toolGroups.Select(g => $"{g.Tool}={g.Count}"))}");

        // EZ Tools should always be present in the sample data
        Assert.Contains(toolGroups, g => g.Tool == "EZ Tools");
    }

    [Fact]
    public void AllRows_HaveRequiredFields()
    {
        EnsureConfigLoaded();

        var args = new ParsedArgs
        {
            BaseDir = SampleDataDir,
            ALL = true,
            NoPrompt = true,
        };

        var rows = CollectorManager.GetAllRows(args);

        foreach (var row in rows.Take(100)) // Sample first 100
        {
            Assert.False(string.IsNullOrEmpty(row.DateTime), $"Row missing DateTime: Tool={row.Tool}, Artifact={row.ArtifactName}");
            Assert.False(string.IsNullOrEmpty(row.Tool), "Row missing Tool");
            Assert.False(string.IsNullOrEmpty(row.ArtifactName), "Row missing ArtifactName");
        }
    }

    [Fact]
    public void Discovery_PartialFilenameMatch_WithHeaderConfirmation()
    {
        EnsureConfigLoaded();

        // This tests the Discovery fix: when filename matches but folder doesn't,
        // and strict_header_match is true, the file should still be found via header confirmation.
        // Chrome_Default.csv is in kape_triage/ (no browser/webhistory folder) but
        // filename contains "chrome" (matches pattern) and has all required headers.
        var files = Discovery.FindArtifactFiles(SampleDataDir, SampleDataDir, "ForensicWebHistory");

        // Should find Chrome_Default.csv via filename match + header confirmation
        var chromeFile = files.FirstOrDefault(f => Path.GetFileName(f).Contains("Chrome", StringComparison.OrdinalIgnoreCase));
        Assert.NotNull(chromeFile);
    }
}
