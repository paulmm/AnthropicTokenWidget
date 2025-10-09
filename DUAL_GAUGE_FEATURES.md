# Dual Gauge Dashboard - Real-Time Token Monitoring

## 🎯 Features Implemented

### Left Gauge: Burn Rate Tachometer
**Real-time velocity tracking showing tokens consumed per minute**

- **Data Collection**: Analyzes all token usage from the last 5 minutes
- **Pattern Analysis**: Identifies consumption trends across overlapping sessions
- **Velocity Tracking**: Calculates precise tokens/minute consumption rate
- **Real-time Updates**: Refreshes every 60 seconds (configurable)
- **Visual Indicators**:
  - Green zone: Safe consumption (below safe rate)
  - Yellow zone: Elevated usage (1-1.5x safe rate)
  - Red zone: Critical usage (>1.5x safe rate)

### Right Gauge: Total Usage Tachometer
**Shows cumulative token usage in current 5-hour window**

- Displays total tokens used
- Shows percentage of limit
- Time until window reset
- Current tier display

## 📊 How It Works

### Burn Rate Calculation
```swift
// Last 5 minutes of actual usage
let fiveMinutesAgo = Date().addingTimeInterval(-300)
let recentEntries = entries.filter { $0.timestamp >= fiveMinutesAgo }

// Sum all tokens and calculate rate
let totalTokens = recentEntries.reduce(0) { $0 + $1.totalTokens }
let burnRate = totalTokens / timeSpanInMinutes
```

### Data Sources
1. **Raw Session Data**: `~/.claude/projects/*.jsonl` files
2. **Input Tokens**: All tokens sent to Claude
3. **Output Tokens**: All tokens received from Claude
4. **Cache Tokens**: Prompt caching creation + reads
5. **Time Resolution**: Second-level precision

### Prediction Engine
- Estimates when tokens will be depleted at current burn rate
- Suggests safe consumption rate to stay within limits
- Calculates time to limit based on velocity
- Adjusts predictions in real-time as usage patterns change

## 🎨 Visual Design

### Dual Gauge Layout
```
┌─────────────────────────────────────────────────────┐
│  BURN RATE              TOTAL USAGE                │
│  ┌──────────┐          ┌──────────┐                │
│  │   250    │          │  45,000  │                │
│  │tokens/min│          │ of 88,000│                │
│  │          │          │   51%    │                │
│  └──────────┘          └──────────┘                │
│  Status: SAFE          Reset: 2h 45m               │
└─────────────────────────────────────────────────────┘
```

### Color Coding
- **Green**: Safe operation, sustainable rate
- **Yellow**: Warning, approaching limits
- **Red**: Critical, exceeding safe rate

## 📈 Real-Time Metrics

### Burn Rate Gauge Shows:
- Current tokens/minute
- Safe consumption rate (green line)
- Peak display rate (max scale)
- Status indicator (SAFE/HIGH/CRITICAL)

### Usage Gauge Shows:
- Total tokens used in window
- Tokens remaining
- Time until reset
- Current account tier

## ⚙️ Configuration

### Settings → Refresh Settings
- **Refresh Interval**: 30-300 seconds (default: 60s)
- **Auto-refresh**: Enabled by default

### Settings → Account
- **Plan Selection**: Custom/Pro/Max5/Max20
- **P90 Detection**: Auto-detects limits on Custom plan

### Settings → Alert Thresholds
- **Warning**: 75% (default) - Yellow zone starts
- **Critical**: 90% (default) - Red zone starts

## 🔄 Update Cycle

1. Every 60 seconds (default):
   - Read all `.jsonl` files from `~/.claude/projects`
   - Parse usage entries with timestamps
   - Calculate burn rate from last 5 minutes
   - Update total usage for current 5-hour window
   - Refresh predictions and alerts

2. UI updates:
   - Gauges animate smoothly to new values
   - Colors transition based on thresholds
   - Stats update in real-time

## 💡 Usage Insights

### When to Watch Burn Rate:
- **During active coding**: Shows if you're using tokens too quickly
- **Long sessions**: Helps pace usage to avoid hitting limits
- **Multiple windows**: Tracks overlapping Claude Code sessions

### What the Gauges Tell You:
- **Low burn rate + low usage**: Plenty of headroom, code freely
- **High burn rate + low usage**: Fast usage but early in window
- **Low burn rate + high usage**: Slowing down, but close to limit
- **High burn rate + high usage**: ⚠️ Critical - slow down or risk hitting limit

## 🎓 Tips for Optimal Usage

1. **Keep burn rate below safe rate line** (green zone)
2. **Monitor both gauges together** for complete picture
3. **Watch for yellow zones** - time to slow down
4. **Red zones** - consider pausing heavy operations
5. **Use predictions** to plan coding sessions

## 🚀 Future Enhancements

Potential additions:
- Historical burn rate chart
- Session-by-session breakdown
- Smart alerts before hitting limits
- Usage recommendations based on patterns
- Export burn rate analytics
