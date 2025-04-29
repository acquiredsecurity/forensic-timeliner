// Utils/TimelineRowJsonContext.cs
using System.Text.Json.Serialization;
using ForensicTimeliner.Models;

namespace ForensicTimeliner.Utils;

[JsonSourceGenerationOptions(WriteIndented = true)]
[JsonSerializable(typeof(List<TimelineRow>))]
public partial class TimelineRowJsonContext : JsonSerializerContext
{
}
