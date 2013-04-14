// Copyright 2004-present Facebook. All Rights Reserved.


#import "PhabricatorReporter.h"

#import "Options.h"
#import "PJSONKit.h"

@implementation PhabricatorReporter

- (id)init
{
  if (self = [super init]) {
    _results = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)dealloc
{
  [_results release];
  [_projectOrWorkspaceName release];
  [super dealloc];
}

- (NSString *)projectOrWorkspaceName
{
  if (_projectOrWorkspaceName == nil) {
    NSString *path = nil;

    if (self.options.workspace) {
      path = self.options.workspace;
    } else {
      path = self.options.project;
    }

    _projectOrWorkspaceName = [[[path lastPathComponent] stringByDeletingPathExtension] retain];
  }

  return _projectOrWorkspaceName;
};


- (void)beginAction:(Action *)action
{
}

- (void)endAction:(Action *)action succeeded:(BOOL)succeeded
{
}

- (void)beginBuildTarget:(NSDictionary *)event
{
  _currentTargetFailures = [[NSMutableArray alloc] init];
}

- (void)endBuildTarget:(NSDictionary *)event
{
  [_results addObject:@{
   @"name" : [NSString stringWithFormat:@"%@: Build %@:%@",
              [self projectOrWorkspaceName],
              event[kReporter_EndBuildTarget_ProjectKey],
              event[kReporter_EndBuildTarget_TargetKey]],
   @"link" : [NSNull null],
   @"result" : (_currentTargetFailures.count == 0) ? @"pass" : @"broken",
   @"userdata" : [_currentTargetFailures componentsJoinedByString:@"=================================\n"],
   @"coverage" : [NSNull null],
   @"extra" : [NSNull null],
   }];

  [_currentTargetFailures release];
  _currentTargetFailures = nil;
}

- (void)beginBuildCommand:(NSDictionary *)event
{
  _currentBuildCommand = [event retain];
}

- (void)endBuildCommand:(NSDictionary *)event
{
  BOOL succeeded = [event[kReporter_EndBuildCommand_SucceededKey] boolValue];
  if (!succeeded) {
    NSString *commandAndFailure =
      [_currentBuildCommand[kReporter_BeginBuildCommand_CommandKey]
       stringByAppendingString:event[kReporter_EndBuildCommand_FailureReasonKey]];
    [_currentTargetFailures addObject:commandAndFailure];
  }

  [_currentBuildCommand release];
  _currentBuildCommand = nil;
}

- (void)beginXcodebuild:(NSDictionary *)event
{
}

- (void)endXcodebuild:(NSDictionary *)event
{
}

- (void)beginOcunit:(NSDictionary *)event
{
}

- (void)endOcunit:(NSDictionary *)event
{
}

- (void)beginTestSuite:(NSDictionary *)event
{
}

- (void)endTestSuite:(NSDictionary *)event
{
}

- (void)beginTest:(NSDictionary *)event
{
}

- (void)endTest:(NSDictionary *)event
{
  NSMutableString *userdata = [NSMutableString stringWithString:event[kReporter_EndTest_OutputKey]];

  // Include exception, if any.
  NSDictionary *exception = event[kReporter_EndTest_ExceptionKey];
  if (exception) {
    [userdata appendFormat:@"%@:%d: %@: %@",
     exception[kReporter_EndTest_Exception_FilePathInProjectKey],
     [exception[kReporter_EndTest_Exception_LineNumberKey] intValue],
     exception[kReporter_EndTest_Exception_NameKey],
     exception[kReporter_EndTest_Exception_ReasonKey]];
  }

  [_results addObject:@{
   @"name" : [NSString stringWithFormat:@"%@: %@",
              [self projectOrWorkspaceName],
              event[kReporter_EndTest_TestKey]],
   @"link" : [NSNull null],
   @"result" : [event[kReporter_EndTest_SucceededKey] boolValue] ? @"pass" : @"fail",
   @"userdata" : userdata,
   @"coverage" : [NSNull null],
   @"extra" : [NSNull null],
   }];
}

- (void)testOutput:(NSDictionary *)event
{
}

- (NSString *)arcUnitJSON
{
  return [_results XT_JSONStringWithOptions:XT_JKSerializeOptionPretty error:nil];
}

- (void)close
{
  [_outputHandle writeData:[[[self arcUnitJSON] stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
  [super close];
}

@end