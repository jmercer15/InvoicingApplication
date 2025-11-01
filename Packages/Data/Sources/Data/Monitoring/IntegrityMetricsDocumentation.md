# Data Integrity Metrics Documentation

## Overview

This document provides comprehensive documentation for the data integrity metrics system. The metrics system tracks, analyzes, and reports on data integrity across all entity types in the application.

## Architecture

### Core Components

1. **DataIntegrityMetrics** - Core metrics collection and storage
2. **IntegrityMetricsCollector** - Automated metrics collection service
3. **IntegrityMetricsReporter** - Report generation and export service
4. **DataIntegrityMonitor** - Real-time integrity monitoring
5. **DataLayerHealthDashboard** - Health status and recommendations

### Metrics Flow

```
Data Integrity Check → Metrics Collection → Analysis → Reporting → Dashboard
```

## Components

### 1. DataIntegrityMetrics

**Purpose**: Core metrics collection and storage for data integrity.

**Key Features**:

- Comprehensive metrics tracking
- Issue categorization and severity tracking
- Trend analysis and health scoring
- Performance metrics collection
- Risk assessment and recommendations

**Usage**:

```swift
let metrics = DataIntegrityMetrics.shared

// Record integrity check
metrics.recordIntegrityCheck(
    entityType: "ClientEntity",
    checkType: .comprehensive,
    duration: 0.5,
    issuesFound: 2,
    totalFieldsChecked: 8
)

// Record specific issue
metrics.recordIntegrityIssue(
    entityType: "ClientEntity",
    issueType: .missingRequiredField,
    severity: .high,
    fieldName: "fullName",
    entityId: "client-123"
)

// Get metrics
let entityMetrics = metrics.getEntityIntegrityMetrics(for: "ClientEntity")
let healthScore = metrics.getIntegrityHealthScore(for: "ClientEntity")
```

**Metrics Tracked**:

- **Check Metrics**: Total checks, duration, fields checked
- **Issue Metrics**: Issue counts, severity, field distribution
- **Trend Metrics**: Issue trends over time
- **Health Metrics**: Overall health scores and assessments
- **Performance Metrics**: Check duration and throughput

### 2. IntegrityMetricsCollector

**Purpose**: Automated collection of integrity metrics across all entity types.

**Key Features**:

- Automated metrics collection
- Entity-specific integrity checks
- Configurable collection intervals
- Collection status monitoring
- Performance tracking

**Usage**:

```swift
let collector = IntegrityMetricsCollector.shared

// Start automated collection
collector.startAutomatedCollection(interval: 300) // 5 minutes

// Collect metrics for specific entities
collector.collectClientEntityMetrics(entities: clientEntities)
collector.collectInvoiceEntityMetrics(entities: invoiceEntities)

// Get collection summary
let summary = collector.generateCollectionSummary()
```

**Collection Features**:

- **Automated Collection**: Scheduled collection at configurable intervals
- **Entity-Specific Checks**: Tailored integrity checks for each entity type
- **Performance Monitoring**: Track collection performance and duration
- **Status Management**: Enable/disable collection and monitor status

### 3. IntegrityMetricsReporter

**Purpose**: Generate comprehensive reports and export metrics data.

**Key Features**:

- Comprehensive report generation
- Multiple export formats (JSON, CSV, Text, HTML)
- Trend analysis reports
- Performance reports
- Risk assessment reports

**Usage**:

```swift
let reporter = IntegrityMetricsReporter.shared

// Generate comprehensive report
let report = reporter.generateComprehensiveReport()

// Generate entity-specific report
let entityReport = reporter.generateEntityReport(for: "ClientEntity")

// Generate summary report
let summary = reporter.generateSummaryReport()

// Export report
try reporter.exportReport(report, format: .json, to: "/path/to/report.json")
```

**Report Types**:

- **Comprehensive Report**: Overall system integrity status
- **Entity Report**: Entity-specific integrity analysis
- **Trend Analysis Report**: Issue trends over time
- **Performance Report**: Collection and check performance
- **Summary Report**: Console-friendly summary format

## Metrics Types

### 1. Check Metrics

#### Operation Metrics

- **Total Checks**: Number of integrity checks performed
- **Check Duration**: Time taken for each check
- **Fields Checked**: Number of fields validated per check
- **Check Frequency**: How often checks are performed

#### Performance Metrics

- **Average Duration**: Average time per check
- **Throughput**: Checks per second
- **Peak Performance**: Maximum check rate
- **Resource Usage**: Memory and CPU usage during checks

### 2. Issue Metrics

#### Issue Categories

- **Missing Required Fields**: Required fields that are nil
- **Invalid Data Format**: Data that doesn't match expected format
- **Type Mismatch**: Data types that don't match expected types
- **Relationship Not Found**: Missing or invalid relationships
- **Data Corruption**: Signs of data corruption

#### Severity Levels

- **Critical**: Issues that cause system failures
- **High**: Issues that affect core functionality
- **Medium**: Issues that affect user experience
- **Low**: Issues that are minor or cosmetic

#### Issue Distribution

- **By Entity Type**: Issues per entity type
- **By Field**: Issues per field
- **By Severity**: Issues per severity level
- **By Time**: Issues over time

### 3. Trend Metrics

#### Trend Analysis

- **Trend Direction**: Increasing, decreasing, or stable
- **Trend Strength**: How strong the trend is
- **Trend Period**: Time period analyzed
- **Trend Predictions**: Future trend predictions

#### Trend Indicators

- **Issue Rate Trends**: How issue rates change over time
- **Health Score Trends**: How health scores change over time
- **Performance Trends**: How performance changes over time
- **Collection Trends**: How collection performance changes

### 4. Health Metrics

#### Health Scores

- **Overall Health Score**: System-wide health assessment
- **Entity Health Score**: Per-entity health assessment
- **Component Health Score**: Per-component health assessment
- **Historical Health Score**: Health score trends over time

#### Health Factors

- **Issue Rate**: Percentage of checks that find issues
- **Validation Success Rate**: Percentage of successful validations
- **Performance Score**: Based on check duration and throughput
- **Consistency Score**: Based on data consistency across entities

### 5. Risk Metrics

#### Risk Assessment

- **Risk Level**: Low, medium, high, or critical
- **Risk Factors**: Specific factors contributing to risk
- **Risk Trends**: How risk levels change over time
- **Risk Predictions**: Future risk level predictions

#### Risk Categories

- **Data Loss Risk**: Risk of losing data
- **Data Corruption Risk**: Risk of data corruption
- **Performance Risk**: Risk of performance degradation
- **System Risk**: Risk of system failure

## Entity-Specific Metrics

### 1. ClientEntity Metrics

#### Checked Fields

- **id**: Required field validation
- **fullName**: Required field and format validation
- **ndisNumber**: Required field validation
- **email**: Format validation
- **phone**: Format validation
- **status**: Value validation
- **address**: Relationship validation
- **planManager**: Relationship validation

#### Common Issues

- **Missing fullName**: High severity
- **Invalid email format**: Medium severity
- **Missing ndisNumber**: High severity
- **Invalid phone format**: Medium severity

### 2. InvoiceEntity Metrics

#### Checked Fields

- **id**: Required field validation
- **invoiceNumber**: Required field validation
- **createdDate**: Date validation
- **dueDate**: Date consistency validation
- **status**: Value validation
- **client**: Relationship validation
- **items**: Relationship validation
- **amount**: Numeric validation

#### Common Issues

- **Missing invoiceNumber**: High severity
- **Invalid date consistency**: Medium severity
- **Missing client relationship**: High severity
- **Invalid amount**: Medium severity

### 3. SessionEntity Metrics

#### Checked Fields

- **id**: Required field validation
- **title**: Required field validation
- **startTime**: Date validation
- **endTime**: Date consistency validation
- **client**: Relationship validation
- **location**: Format validation
- **notes**: Content validation
- **status**: Value validation

#### Common Issues

- **Missing title**: High severity
- **Invalid time consistency**: Medium severity
- **Missing client relationship**: High severity
- **Invalid location format**: Low severity

### 4. TravelChargeEntity Metrics

#### Checked Fields

- **id**: Required field validation
- **travelDistance**: Numeric validation
- **travelDuration**: Numeric validation
- **parkingCost**: Numeric validation
- **tollCost**: Numeric validation
- **linkedSession**: Relationship validation
- **client**: Relationship validation
- **status**: Value validation

#### Common Issues

- **Negative distance**: Medium severity
- **Negative duration**: Medium severity
- **Missing session relationship**: High severity
- **Invalid cost values**: Medium severity

### 5. NDISItemEntity Metrics

#### Checked Fields

- **id**: Required field validation
- **itemNumber**: Required field validation
- **name**: Required field validation
- **description**: Content validation
- **category**: Value validation
- **effectiveStartDate**: Date validation
- **effectiveEndDate**: Date consistency validation
- **status**: Value validation

#### Common Issues

- **Missing itemNumber**: High severity
- **Missing name**: High severity
- **Invalid date consistency**: Medium severity
- **Missing category**: Medium severity

## Health Assessment

### 1. Health Score Calculation

#### Formula

```
Health Score = (1 - Issue Rate) × Validation Success Rate × Performance Score
```

#### Components

- **Issue Rate**: Percentage of checks that find issues
- **Validation Success Rate**: Percentage of successful validations
- **Performance Score**: Based on check duration and throughput

#### Score Ranges

- **0.9 - 1.0**: Excellent health
- **0.8 - 0.9**: Good health
- **0.7 - 0.8**: Fair health
- **0.6 - 0.7**: Poor health
- **0.0 - 0.6**: Critical health

### 2. Risk Assessment

#### Risk Level Calculation

```
Risk Level = f(Health Score, Issue Severity, Trend Direction, Issue Count)
```

#### Risk Factors

- **Health Score**: Lower scores increase risk
- **Issue Severity**: Higher severity increases risk
- **Trend Direction**: Increasing trends increase risk
- **Issue Count**: More issues increase risk

#### Risk Levels

- **Low**: Health score > 0.8, few issues, stable trends
- **Medium**: Health score 0.6-0.8, some issues, stable trends
- **High**: Health score 0.4-0.6, many issues, increasing trends
- **Critical**: Health score < 0.4, critical issues, increasing trends

## Reporting

### 1. Report Types

#### Comprehensive Report

- **Overall Health Score**: System-wide health assessment
- **Entity Metrics**: Per-entity health and performance
- **Critical Issues**: Issues requiring immediate attention
- **Trending Issues**: Issues trending upward
- **Recommendations**: Actionable recommendations
- **Risk Assessment**: Overall risk level and factors

#### Entity Report

- **Entity Health Score**: Entity-specific health assessment
- **Issue Breakdown**: Issues by type and severity
- **Trend Analysis**: Issue trends over time
- **Performance Metrics**: Check duration and throughput
- **Recommendations**: Entity-specific recommendations
- **Risk Assessment**: Entity-specific risk level

#### Trend Analysis Report

- **Trend Data**: Trend analysis for all entities
- **Overall Trend**: System-wide trend direction
- **Trend Predictions**: Future trend predictions
- **Recommendations**: Trend-based recommendations

#### Performance Report

- **Total Checks**: Number of checks performed
- **Average Duration**: Average check duration
- **Slowest Entity**: Entity with slowest checks
- **Fastest Entity**: Entity with fastest checks
- **Collection Performance**: Collection efficiency
- **Recommendations**: Performance-based recommendations

### 2. Export Formats

#### JSON Export

```json
{
  "generatedAt": "2024-01-01T00:00:00Z",
  "overallHealthScore": 0.85,
  "totalEntityTypes": 5,
  "totalChecks": 1000,
  "totalIssues": 50,
  "criticalIssues": [],
  "trendingIssues": [],
  "entityMetrics": {
    "ClientEntity": {
      "healthScore": 0.9,
      "totalChecks": 200,
      "totalIssues": 10
    }
  }
}
```

#### CSV Export

```csv
Entity Type,Health Score,Total Checks,Total Issues,Issue Rate
ClientEntity,0.9,200,10,5.0
InvoiceEntity,0.85,150,8,5.3
SessionEntity,0.8,180,12,6.7
```

#### Text Export

```
========================================
DATA INTEGRITY SUMMARY REPORT
========================================
Generated: Jan 1, 2024 at 12:00:00 AM

OVERALL HEALTH SCORE: 85%

ENTITY METRICS:

ClientEntity:
  Health Score: 90%
  Total Checks: 200
  Total Issues: 10
  Issue Rate: 5.0%
  Validation Success: 95%
  Average Check Duration: 45ms
```

#### HTML Export

```html
<!DOCTYPE html>
<html>
  <head>
    <title>Data Integrity Report</title>
    <style>
      .health-score {
        color: green;
      }
      .critical-issues {
        color: red;
      }
      .trending-issues {
        color: orange;
      }
    </style>
  </head>
  <body>
    <h1>Data Integrity Report</h1>
    <p>Overall Health Score: <span class="health-score">85%</span></p>
    <h2>Critical Issues</h2>
    <ul class="critical-issues">
      <li>No critical issues found</li>
    </ul>
    <h2>Trending Issues</h2>
    <ul class="trending-issues">
      <li>No trending issues found</li>
    </ul>
  </body>
</html>
```

## Configuration

### 1. Collection Configuration

#### Collection Settings

```swift
let collector = IntegrityMetricsCollector.shared

// Enable/disable collection
collector.setCollectionEnabled(true)

// Set collection interval
collector.startAutomatedCollection(interval: 300) // 5 minutes

// Stop collection
collector.stopAutomatedCollection()
```

#### Collection Intervals

- **Development**: 60 seconds (frequent monitoring)
- **Testing**: 300 seconds (5 minutes)
- **Production**: 1800 seconds (30 minutes)
- **Debug**: 30 seconds (very frequent monitoring)

### 2. Metrics Configuration

#### Metrics Retention

```swift
let metrics = DataIntegrityMetrics.shared

// Clear old metrics
metrics.clearOldMetrics(olderThan: Date().addingTimeInterval(-3600)) // 1 hour
```

#### Retention Periods

- **Development**: 1 hour
- **Testing**: 6 hours
- **Production**: 24 hours
- **Debug**: 30 minutes

### 3. Reporting Configuration

#### Report Generation

```swift
let reporter = IntegrityMetricsReporter.shared

// Generate reports
let comprehensiveReport = reporter.generateComprehensiveReport()
let entityReport = reporter.generateEntityReport(for: "ClientEntity")
let trendReport = reporter.generateTrendAnalysisReport()
let performanceReport = reporter.generatePerformanceReport()
```

#### Export Configuration

```swift
// Export to different formats
try reporter.exportReport(report, format: .json, to: "/path/to/report.json")
try reporter.exportReport(report, format: .csv, to: "/path/to/report.csv")
try reporter.exportReport(report, format: .text, to: "/path/to/report.txt")
try reporter.exportReport(report, format: .html, to: "/path/to/report.html")
```

## Usage Examples

### 1. Basic Metrics Collection

```swift
let metrics = DataIntegrityMetrics.shared

// Record integrity check
metrics.recordIntegrityCheck(
    entityType: "ClientEntity",
    checkType: .comprehensive,
    duration: 0.5,
    issuesFound: 2,
    totalFieldsChecked: 8
)

// Record specific issue
metrics.recordIntegrityIssue(
    entityType: "ClientEntity",
    issueType: .missingRequiredField,
    severity: .high,
    fieldName: "fullName",
    entityId: "client-123"
)

// Get metrics
let entityMetrics = metrics.getEntityIntegrityMetrics(for: "ClientEntity")
print("Health Score: \(entityMetrics.healthScorePercentage)%")
```

### 2. Automated Collection

```swift
let collector = IntegrityMetricsCollector.shared

// Start automated collection
collector.startAutomatedCollection(interval: 300)

// Collect metrics for specific entities
collector.collectClientEntityMetrics(entities: clientEntities)
collector.collectInvoiceEntityMetrics(entities: invoiceEntities)

// Get collection summary
let summary = collector.generateCollectionSummary()
print("Total Checks: \(summary.totalChecks)")
print("Total Issues: \(summary.totalIssues)")
print("Issue Rate: \(summary.issueRatePercentage)%")
```

### 3. Report Generation

```swift
let reporter = IntegrityMetricsReporter.shared

// Generate comprehensive report
let report = reporter.generateComprehensiveReport()
print("Overall Health Score: \(report.overallHealthScorePercentage)%")
print("Critical Issues: \(report.criticalIssues.count)")
print("Trending Issues: \(report.trendingIssues.count)")

// Generate entity-specific report
let entityReport = reporter.generateEntityReport(for: "ClientEntity")
print("Entity Health Score: \(entityReport.healthScorePercentage)%")

// Generate summary report
let summary = reporter.generateSummaryReport()
print(summary)
```

### 4. Export Reports

```swift
let reporter = IntegrityMetricsReporter.shared
let report = reporter.generateComprehensiveReport()

// Export to different formats
try reporter.exportReport(report, format: .json, to: "/path/to/report.json")
try reporter.exportReport(report, format: .csv, to: "/path/to/report.csv")
try reporter.exportReport(report, format: .text, to: "/path/to/report.txt")
try reporter.exportReport(report, format: .html, to: "/path/to/report.html")
```

## Best Practices

### 1. Metrics Collection

1. **Regular Collection**: Set up automated collection at appropriate intervals
2. **Entity Coverage**: Ensure all entity types are covered
3. **Performance Monitoring**: Monitor collection performance
4. **Resource Management**: Manage metrics storage and retention

### 2. Issue Tracking

1. **Severity Classification**: Use appropriate severity levels
2. **Issue Categorization**: Categorize issues by type and entity
3. **Trend Monitoring**: Monitor issue trends over time
4. **Root Cause Analysis**: Investigate root causes of issues

### 3. Health Assessment

1. **Regular Assessment**: Assess health regularly
2. **Threshold Monitoring**: Monitor health score thresholds
3. **Trend Analysis**: Analyze health trends over time
4. **Action Planning**: Plan actions based on health assessments

### 4. Reporting

1. **Regular Reporting**: Generate reports regularly
2. **Multiple Formats**: Use multiple export formats
3. **Stakeholder Communication**: Share reports with stakeholders
4. **Action Tracking**: Track actions based on reports

## Troubleshooting

### Common Issues

#### High Memory Usage

- **Cause**: Too many metrics retained in memory
- **Solution**: Reduce metrics retention period
- **Prevention**: Regular cleanup of old metrics

#### Slow Collection

- **Cause**: Collection overhead too high
- **Solution**: Increase collection interval
- **Prevention**: Optimize collection logic

#### Missing Metrics

- **Cause**: Collection not enabled or entities not being checked
- **Solution**: Enable collection and ensure entity coverage
- **Prevention**: Monitor collection status

#### Inaccurate Health Scores

- **Cause**: Incorrect metrics or calculation issues
- **Solution**: Review metrics collection and calculation logic
- **Prevention**: Regular validation of health score calculations

### Debugging

#### Enable Debug Logging

```swift
let metrics = DataIntegrityMetrics.shared
let collector = IntegrityMetricsCollector.shared
let reporter = IntegrityMetricsReporter.shared

// Check collection status
let summary = collector.generateCollectionSummary()
print("Collection Enabled: \(summary.collectionEnabled)")

// Check metrics
let allMetrics = metrics.getAllIntegrityMetrics()
for (entityType, entityMetrics) in allMetrics {
    print("\(entityType): \(entityMetrics.healthScorePercentage)%")
}

// Generate debug report
let report = reporter.generateComprehensiveReport()
print("Overall Health: \(report.overallHealthScorePercentage)%")
```

#### Monitor Collection Performance

```swift
let collector = IntegrityMetricsCollector.shared

// Check collection summary
let summary = collector.generateCollectionSummary()
print("Total Checks: \(summary.totalChecks)")
print("Total Issues: \(summary.totalIssues)")
print("Issue Rate: \(summary.issueRatePercentage)%")
print("Last Collection: \(summary.lastCollection)")
print("Next Collection: \(summary.nextCollection)")
```

## Conclusion

The data integrity metrics system provides comprehensive visibility into data integrity across all entity types. By following the best practices and using the appropriate configurations, you can ensure optimal data quality and system health.

The metrics system is designed to be:

- **Comprehensive**: Covers all aspects of data integrity
- **Automated**: Minimal manual intervention required
- **Configurable**: Adaptable to different environments
- **Actionable**: Provides clear recommendations and insights
- **Scalable**: Handles large volumes of data efficiently
