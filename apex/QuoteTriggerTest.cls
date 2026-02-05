@IsTest
private class QuoteTriggerTest {

    private static User createTestManagerUser() {
        Profile p = [SELECT Id FROM Profile WHERE UserType = 'Standard' LIMIT 1];

        User u = new User(
            FirstName = 'Test',
            LastName  = 'Manager',
            Email     = 'test.manager@example.com',
            Username  = 'test.manager.' + System.currentTimeMillis() + '@example.com',
            Alias     = 'tman',
            TimeZoneSidKey     = 'America/Los_Angeles',
            LocaleSidKey       = 'en_US',
            EmailEncodingKey   = 'UTF-8',
            LanguageLocaleKey  = 'en_US',
            ProfileId          = p.Id
        );
        insert u;
        return u;
    }

    private static Opportunity createOpportunity() {
        Account a = new Account(Name = 'Test Account');
        insert a;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 100,
            AccountId = a.Id
        );
        insert opp;
        return opp;
    }

    @IsTest
    static void testLatestApprovedQuoteWins() {
        User manager = createTestManagerUser();
        Opportunity opp = createOpportunity();


        Quote q1 = new Quote(
            Name = 'Quote 1',
            OpportunityId = opp.Id,
            Discount__c = 10,
            Approval_Status__c = 'Draft',
            Total_Amount__c = 500,
            Manager__c = manager.Id
        );
        Quote q2 = new Quote(
            Name = 'Quote 2',
            OpportunityId = opp.Id,
            Discount__c = 10,
            Approval_Status__c = 'Draft',
            Total_Amount__c = 900,
            Manager__c = manager.Id
        );
        insert new List<Quote>{ q1, q2 };


        q1.Approval_Status__c = 'Approved';
        q2.Approval_Status__c = 'Approved';

        Test.startTest();
        update q1;
        update q2;
        Test.stopTest();

        Opportunity oppCheck = [SELECT Amount FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(900, oppCheck.Amount, 'Most recently approved Quote should update Opportunity.Amount');
    }

    @IsTest
    static void testBulkApprovalsAcrossMultipleOpportunities() {
        User manager = createTestManagerUser();

        Account a = new Account(Name = 'Bulk Account');
        insert a;

        Opportunity opp1 = new Opportunity(Name='Opp 1', StageName='Prospecting', CloseDate=Date.today().addDays(10), Amount=0, AccountId=a.Id);
        Opportunity opp2 = new Opportunity(Name='Opp 2', StageName='Prospecting', CloseDate=Date.today().addDays(10), Amount=0, AccountId=a.Id);
        insert new List<Opportunity>{ opp1, opp2 };

        Quote q1 = new Quote(
            Name='Q1',
            OpportunityId=opp1.Id,
            Approval_Status__c='Draft',
            Discount__c=10,
            Total_Amount__c=111,
            Manager__c=manager.Id
        );
        Quote q2 = new Quote(
            Name='Q2',
            OpportunityId=opp2.Id,
            Approval_Status__c='Draft',
            Discount__c=10,
            Total_Amount__c=222,
            Manager__c=manager.Id
        );
        insert new List<Quote>{ q1, q2 };

        q1.Approval_Status__c = 'Approved';
        q2.Approval_Status__c = 'Approved';

        Test.startTest();
        update new List<Quote>{ q1, q2 };
        Test.stopTest();

        Map<Id, Opportunity> opps = new Map<Id, Opportunity>([
            SELECT Id, Amount
            FROM Opportunity
            WHERE Id IN :new List<Id>{ opp1.Id, opp2.Id }
        ]);

        System.assertEquals(111, opps.get(opp1.Id).Amount);
        System.assertEquals(222, opps.get(opp2.Id).Amount);
    }
}