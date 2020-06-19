/**
 * loadCaltoContactTracingTest - test class for loadCaltoContactTracing
 **/
@isTest
private class loadCaltoContactTracingTest {
    @isTest
    static void testShiftToTracing() {
        /**
         * Create test data
         **/
        // Create test Users
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
		List<User> tUsers = new List<User>();
        User u1 = new User(FirstName='Employee',LastName='1',EmployeeNumber='EE-9999901',Email='test1@example.com',Alias='test1',EmailEncodingKey='UTF-8',LanguageLocaleKey='en_US',LocaleSidKey='en_US',ProfileId=p.Id,TimeZoneSidKey='America/Los_Angeles', UserName='test1@mrhtestcode1.com');
        tUsers.add(u1);
        User u2 = new User(FirstName='Employee',LastName='2',EmployeeNumber='EE-9999902',Email='test2@example.com',Alias='test1',EmailEncodingKey='UTF-8',LanguageLocaleKey='en_US',LocaleSidKey='en_US',ProfileId=p.Id,TimeZoneSidKey='America/Los_Angeles', UserName='test2@mrhtestcode1.com');
        tUsers.add(u2);
        try {
            Database.SaveResult[] r0 = Database.insert(tUsers,false);
		} catch(DmlException e) {
    		System.debug('The following exception has occurred: ' + e.getMessage());
		}
        //System.Debug('u1.Id: '+u1.Id);

        // Create test PersonAccounts
        RecordType paRT = [SELECT Id FROM RecordType WHERE Name = 'Person Account' and SObjectType = 'Account'];
		List<Account> tPAs = new List<Account>();
        Account p1 = new Account(FirstName='Employee',LastName='1',HealthCloudGA__SourceSystemId__pc='EE-9999901',RecordType=paRT);
		tPAs.add(p1);
        Account p2 = new Account(FirstName='Employee',LastName='2',HealthCloudGA__SourceSystemId__pc='EE-9999902',RecordType=paRT);
		tPAs.add(p2);
        try {
        	Database.SaveResult[] r1 = Database.insert(tPAs,false);
		} catch(DmlException e) {
    		System.debug('The following exception has occurred: ' + e.getMessage());
		}
        //System.Debug('p1.Id: '+p1.Id);
       
       // Create Events
        List<Event> tEvs = new List<Event>();
        DateTime adt1 = DateTime.newInstance(2020,6,1,9,0,0);
        DateTime edt1 = DateTime.newInstance(2020,6,1,10,0,0);
        Event e1 = new Event(OwnerId=u1.Id,Subject='Meeting 1',ActivityDateTime=adt1,EndDateTime=edt1);
        tEvs.add(e1);
        DateTime adt2 = DateTime.newInstance(2020,6,2,9,0,0);
        DateTime edt2 = DateTime.newInstance(2020,6,2,10,0,0);
        Event e2 = new Event(OwnerId=u2.Id,Subject='Meeting 2',ActivityDateTime=adt2,EndDateTime=edt2);
        tEvs.add(e2);
        try {
        	Database.SaveResult[] r2 = Database.insert(tEvs,false);
		} catch(DmlException e) {
    		System.debug('The following exception has occurred: ' + e.getMessage());
		}
        System.Debug(tEvs);
        System.Debug('e1.Id: '+e1.Id);

        // Create EventRelations
        List<EventRelation> tERs = new List<EventRelation>();
        EventRelation er1 = new EventRelation(EventId=e1.Id,RelationId=u2.Id);
        tERs.add(er1);
        EventRelation er2 = new EventRelation(EventId=e2.Id,RelationId=u1.Id);
        tERs.add(er2);
        try {
        	Database.SaveResult[] r3 = Database.insert(tERs,false);
		} catch(DmlException e) {
    		System.debug('The following exception has occurred: ' + e.getMessage());
		}
        System.Debug(tERs);
        System.Debug('er1.Id: '+er1.Id);

        /**
         * Test loadCaltoContactTracing
         **/
		Test.startTest();
        Date tStartDate = Date.newInstance(2020, 5, 1);
        Date tEndDate = Date.newInstance(2020, 12, 1);
        List<loadCaltoContactTracing.employeesInputs> tInputs= new List<loadCaltoContactTracing.employeesInputs>();
        loadCaltoContactTracing.employeesInputs tInput = new loadCaltoContactTracing.employeesInputs();
        tInput.employeeNumber='EE-9999901';
        tInput.userId=u1.Id;
        tInput.startDate=tStartDate;
        tInput.endDate=tEndDate;
        tInputs.add(tInput);
		loadCaltoContactTracing.loadCaltoContactTracing(tInputs);        

        /**
         * Validate
         * TO DO: Improve on the VERY light validation here which is just to achieve code coverage
         * 	for packaging for a demo component
         **/
        ContactEncounter ceVal = [SELECT Id FROM ContactEncounter WHERE Name LIKE 'Calendar Event: %' LIMIT 1];
        System.assert(ceVal != null); 
        ContactEncounterParticipant cepVal = [SELECT Id FROM ContactEncounterParticipant LIMIT 1];
        System.assert(cepVal != null); 

        Test.stopTest();
    }
}