
namespace ForensicTimeliner
{
    public static class TimelineState
    {
        public static int RowCountCollected { get; set; } = 0;
        public static int RowCountAfterDateFilter { get; set; } = 0;
        public static int RowCountAfterDedup { get; set; } = 0;

        public static int RowsFilteredByDate => RowCountCollected - RowCountAfterDateFilter;
        public static int RowsDeduplicated => RowCountAfterDateFilter - RowCountAfterDedup;
    }
}
