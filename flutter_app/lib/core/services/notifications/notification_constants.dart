// Centralized notification constants & helpers.
// Extracted from monolithic notification_service.dart to improve cohesion.

const int kPersistentTimerNotificationId = 1;
const String kActionPause = 'pause_timer';
const String kActionResume = 'resume_timer';
const String kActionStop = 'stop_timer';
const String kActionMarkComplete = 'mark_complete';
const String kActionContinueWorking = 'continue_working';
const String kPayloadOpenApp = 'open_app';

String mapActionLabel(String id) {
  switch (id) {
    case kActionPause:
      return 'Pause';
    case kActionResume:
      return 'Resume';
    case kActionStop:
      return 'Stop';
    case kActionMarkComplete:
      return 'Complete';
    case kActionContinueWorking:
      return 'Continue';
    default:
      return id;
  }
}
