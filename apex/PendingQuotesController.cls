public with sharing class PendingQuotesController {

    @AuraEnabled(cacheable=true)
    public static List<Quote> getPendingQuotes() {
        Id currentUserId = UserInfo.getUserId();

        return [
            SELECT Id, Name, Discount__c, Total_Amount__c,
                   OpportunityId, Opportunity.Name,
                   Manager__c, Approval_Status__c
            FROM Quote
            WHERE Approval_Status__c = 'Pending Approval'
              AND Manager__c = :currentUserId
            ORDER BY LastModifiedDate DESC
            LIMIT 200
        ];
    }

    @AuraEnabled
    public static void approveQuote(Id quoteId) {
        try {
            Quote q = [
                SELECT Id, Approval_Status__c
                FROM Quote
                WHERE Id = :quoteId
                LIMIT 1
                FOR UPDATE
            ];

            q.Approval_Status__c = 'Approved';
            update q;

        } catch (Exception e) {
            throw new AuraHandledException('Approve failed: ' + e.getMessage());
        }
    }
}