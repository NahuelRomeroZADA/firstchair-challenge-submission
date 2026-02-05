trigger QuoteTrigger on Quote (after insert, after update) {
    if (Trigger.isAfter) {
        QuoteTriggerHandler.handleAfter(Trigger.new, Trigger.oldMap);
    }
}