@IsTest
private class QuoteTriggerTest {

    // Crea un usuario "manager" de prueba para poder completar el lookup Manager__c
    private static User createTestManagerUser() {

        // agarro un profile standard cualquiera (para que el user sea válido)
        Profile profileStandard = [
            SELECT Id
            FROM Profile
            WHERE UserType = 'Standard'
            LIMIT 1
        ];

        User u = new User();
        u.FirstName = 'Test';
        u.LastName  = 'Manager';
        u.Email     = 'test.manager@example.com';

        // Username tiene que ser único en Salesforce sí o sí
        u.Username  = 'test.manager.' + System.currentTimeMillis() + '@example.com';

        u.Alias            = 'tman';
        u.TimeZoneSidKey   = 'America/Los_Angeles';
        u.LocaleSidKey     = 'en_US';
        u.EmailEncodingKey = 'UTF-8';
        u.LanguageLocaleKey= 'en_US';
        u.ProfileId        = profileStandard.Id;

        insert u;
        return u;
    }

    // Crea Account + Opportunity de prueba
    private static Opportunity createOpportunity() {

        Account acc = new Account();
        acc.Name = 'Test Account';
        insert acc;

        Opportunity opp = new Opportunity();
        opp.Name = 'Test Opp';
        opp.StageName = 'Prospecting';
        opp.CloseDate = Date.today().addDays(30);
        opp.Amount = 100;
        opp.AccountId = acc.Id;

        insert opp;
        return opp;
    }

    @IsTest
    static void testLatestApprovedQuoteWins() {

        // 1) Setup básico (user + opp)
        User managerUser = createTestManagerUser();
        Opportunity testOpp = createOpportunity();

        // 2) Creo dos quotes en Draft (todavía no ejecutan nada)
        Quote quote1 = new Quote();
        quote1.Name = 'Quote 1';
        quote1.OpportunityId = testOpp.Id;
        quote1.Discount__c = 10;
        quote1.Approval_Status__c = 'Draft';
        quote1.Total_Amount__c = 500;
        quote1.Manager__c = managerUser.Id;

        Quote quote2 = new Quote();
        quote2.Name = 'Quote 2';
        quote2.OpportunityId = testOpp.Id;
        quote2.Discount__c = 10;
        quote2.Approval_Status__c = 'Draft';
        quote2.Total_Amount__c = 900;
        quote2.Manager__c = managerUser.Id;

        insert new List<Quote>{ quote1, quote2 };

        // 3) Ahora las paso a Approved (acá es donde el trigger debería actualizar Opportunity.Amount)
        quote1.Approval_Status__c = 'Approved';
        quote2.Approval_Status__c = 'Approved';

        Test.startTest();

        // las actualizo una por una para simular "se aprobó una y después la otra"
        update quote1;
        update quote2;

        Test.stopTest();

        // 4) Chequeo: como quote2 fue la última en aprobarse, gana y debe dejar Amount = 900
        Opportunity oppAfter = [
            SELECT Amount
            FROM Opportunity
            WHERE Id = :testOpp.Id
        ];

        System.assertEquals(
            900,
            oppAfter.Amount,
            'La última Quote aprobada debería dejar el Amount en 900'
        );
    }

    @IsTest
    static void testBulkApprovalsAcrossMultipleOpportunities() {

        // 1) Setup: user manager
        User managerUser = createTestManagerUser();

        // 2) Creo una cuenta para las dos oportunidades
        Account bulkAccount = new Account();
        bulkAccount.Name = 'Bulk Account';
        insert bulkAccount;

        // 3) Creo dos opportunities
        Opportunity opp1 = new Opportunity();
        opp1.Name = 'Opp 1';
        opp1.StageName = 'Prospecting';
        opp1.CloseDate = Date.today().addDays(10);
        opp1.Amount = 0;
        opp1.AccountId = bulkAccount.Id;

        Opportunity opp2 = new Opportunity();
        opp2.Name = 'Opp 2';
        opp2.StageName = 'Prospecting';
        opp2.CloseDate = Date.today().addDays(10);
        opp2.Amount = 0;
        opp2.AccountId = bulkAccount.Id;

        insert new List<Opportunity>{ opp1, opp2 };

        // 4) Creo una quote para cada opp (en Draft)
        Quote quoteOpp1 = new Quote();
        quoteOpp1.Name = 'Q1';
        quoteOpp1.OpportunityId = opp1.Id;
        quoteOpp1.Approval_Status__c = 'Draft';
        quoteOpp1.Discount__c = 10;
        quoteOpp1.Total_Amount__c = 111;
        quoteOpp1.Manager__c = managerUser.Id;

        Quote quoteOpp2 = new Quote();
        quoteOpp2.Name = 'Q2';
        quoteOpp2.OpportunityId = opp2.Id;
        quoteOpp2.Approval_Status__c = 'Draft';
        quoteOpp2.Discount__c = 10;
        quoteOpp2.Total_Amount__c = 222;
        quoteOpp2.Manager__c = managerUser.Id;

        insert new List<Quote>{ quoteOpp1, quoteOpp2 };

        // 5) Las apruebo a las dos
        quoteOpp1.Approval_Status__c = 'Approved';
        quoteOpp2.Approval_Status__c = 'Approved';

        Test.startTest();

        // update bulk (las dos juntas) para probar que el trigger es bulk-safe
        update new List<Quote>{ quoteOpp1, quoteOpp2 };

        Test.stopTest();

        // 6) Traigo las dos opportunities y verifico que cada una quedó con su amount correcto
        List<Opportunity> oppsAfter = [
            SELECT Id, Amount
            FROM Opportunity
            WHERE Id IN :new List<Id>{ opp1.Id, opp2.Id }
        ];

        // armo mapa para buscar fácil por id (más cómodo para asserts)
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>();
        for (Opportunity o : oppsAfter) {
            oppMap.put(o.Id, o);
        }

        System.assertEquals(111, oppMap.get(opp1.Id).Amount, 'Opp 1 debería quedar con 111');
        System.assertEquals(222, oppMap.get(opp2.Id).Amount, 'Opp 2 debería quedar con 222');
    }
}
