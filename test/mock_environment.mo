/// Mock environment utilities for testing
/// 
/// Since mops test runs in interpreter mode without timer support,
/// we avoid creating actual TimerTool/Local_log instances in tests.
/// Instead, we use null environments and handle them gracefully in the core code.
module {
  
  /// Documentation of what a full environment contains:
  /// - tt: TimerTool instance for scheduling actions  
  /// - advanced: Optional ICRC85 configuration
  /// - log: Local_log instance for debugging/logging
  ///
  /// For testing, we pass null and handle it conditionally in inspector.mo
  
}
