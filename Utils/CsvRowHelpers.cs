// Utils/CsvRowHelpers.cs
namespace ForensicTimeliner.Utils;

public static class CsvRowHelpers
{
    public static string GetString(this IDictionary<string, object> dict, string key)
    {
        return dict.TryGetValue(key, out var val) ? val?.ToString() ?? string.Empty : string.Empty;
    }

    public static long GetLong(this IDictionary<string, object> dict, string key)
    {
        return long.TryParse(GetString(dict, key), out var result) ? result : 0;
    }

    public static DateTime? GetDateTime(this IDictionary<string, object> dict, string key)
    {
        return DateTime.TryParse(GetString(dict, key), out var dt) ? dt : null;
    }
}
