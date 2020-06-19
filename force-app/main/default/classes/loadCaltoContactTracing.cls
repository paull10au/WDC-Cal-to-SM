/**
 * loadCaltoContactTracing - copy calendar entries the Salesforce Activities to contact encounters and participants
 * 	for a given person account in contact tracing
 **/
global class loadCaltoContactTracing {
    /**
     * employeesInputs - Class for capturing input variables from the Flow
     */
    global class employeesInputs {
        // Employee number of the affected employee
        @InvocableVariable
        global String employeeNumber;

        // User.Id for the affected employee
        @InvocableVariable
        global String userId;
        
        // Start date for the search
        @InvocableVariable
        global Date startDate;

        // End date for the search
        @InvocableVariable
        global Date endDate;
    }
    
    /**
     * ceClass - Class for storing key information about the event/encounter when iterating over affected calendar entries
     * This information is then used to find peers who attended the same meetings
     */
    public class ceClass {
        public Id erId; // EventRelation Id
        public Id eId;  // Event Id
        public DateTime startDateTime; // Start of event
        public DateTime endDateTime; // End of event
        public String ceName; // Name of Contact Encounter associated with this shift
        public Integer ceDuration; // Duration of the event
    }
    
    /**
     * getCEIDfromName - Get a ContactEncounter Id from a list of Contact Encounters given a ContactEncounter.Name
     * Input:
     *  encounteList - list of ContactEnter sObjects
     *  encounterName - a ConatactEncounter.Name
     * Output:
     *  Id - ContactEncounter.Id for the Encounter with ContactEncounter.Name = encounterName
     **/
    public static Id getCEIdfromName(List<ContactEncounter> encounterList,String encounterName) {
        for (ContactEncounter ce : encounterList){
     		if(ce.Name.equals(encounterName)){
         		return ce.Id;
     		}
		}
		return null;
    }

    /**
     * getCIdfromENum - Get Contact Id from Employee Number
     * Input:
     *  employeeList - list of Contact sObjects
     *  employeeNumber - an employeeNumber used by Contact.HealthCloudGA__SourceSystemId__c
     * Output:
     *  Id - Contact.Id for the Contact with Contact.HealthCloudGA__SourceSystemId__c = employeeNumber
     **/
    public static Id getCIdfromENum(List<Contact> employeeList, String employeeNumber) {
        for (Contact c : employeeList){
     		if(c.HealthCloudGA__SourceSystemId__c.equals(employeeNumber)){
         		return c.Id;
     		}
		}
		return null;
    }

    /**
     * loadCaltoContactTracing - invoked from a Flow to load calendar information from Salesforce Events to contact encounters 
     *  and participants for a given person account in contact tracing
     * Input:
     *  inputVars - see employeesInputs class definition
     *  TO DO: Determine if this works properly with recurring Events
     *  TO DO: Provide option to only include Events where the affected employee did not decline the invite (Status != 'Declined')
     */
    @InvocableMethod(label='Load Calendar Meetings for Contact Tracing')
    global static void loadCaltoContactTracing(List<employeesInputs> inputVars) {
        String affectedEmployeeNumber = inputVars[0].employeeNumber;
		// Set the startDateTime to the beginning of the day of the inputStartDateTime
        // TO DO: adjust/test for timezones; currently using default GMT
        Time startTimeDay = Time.newInstance(0,0,0,0);
        Time endTimeDay = Time.newInstance(23,59,59,99);
        DateTime startDateTime = DateTime.newInstance(inputVars[0].startDate, startTimeDay);
		// Set the endDateTime to the beginning of the day of the inputEndDateTime
        // TO DO: adjust/test for timezones; currently using default GMT
        DateTime endDateTime = DateTime.newInstance(inputVars[0].endDate, endTimeDay);

        /**
         * Get shared Events for this employee and generate list of ContactEncounters
         **/
        // Create a list to store the ContactEncounters generated
        List<ContactEncounter> newContactEncounters = new List<ContactEncounter>();
        // Create a list to store affected Events so that we can later query them for all attendees
        List<Id> impactedEventIds = new List<Id>();
        // Create a list of key Event information needed to insert ContactEncounters
        List<ceClass> impactedEvents = new List<ceClass>();
        // Get all group Events in which this employee (User) is either the owner or a participant (Relation) 
        String thisDateString;
        for (EventRelation er : [SELECT Id,EventId,Event.OwnerId,RelationId,Event.Subject,Event.ActivityDateTime,Event.EndDateTime,Event.DurationInMinutes,Relation.Name 
                FROM EventRelation 
                WHERE Event.IsGroupEvent = TRUE AND Relation.Type = 'User' AND (Event.OwnerId=:inputVars[0].userId OR RelationId=:inputVars[0].userId) 
                AND Event.ActivityDate >= :inputVars[0].startDate AND Event.ActivityDate <= :inputVars[0].endDate]) {
           /**
             * Generate ContactEncounter for this Event and add it to the list
             **/
            ContactEncounter ce = new ContactEncounter();
            ce.StartTime=er.Event.ActivityDateTime;
            // Generate ContactEncounter name
            //  Note that this format is checked for later so if you change it, change it later in the code as well
            ce.Name = 'Calendar Event: ' + er.Event.Subject + ' on ' + er.Event.ActivityDateTime;
            ce.Description = 'Encounter generated from Calendar Event';
            ce.EncounterDuration = er.Event.DurationInMinutes;
			newContactEncounters.add(ce);

            // Track affected Events
            impactedEventIds.add(er.EventId);

            // Store key information from affected Events in a ceClass list
            //  This is the information needed to find peers who attended the same Events as this employee
            ceClass e = new ceClass();
            e.erId = er.Id;
            e.eId = er.EventId;
            e.startDateTime = er.Event.ActivityDateTime;
            e.endDateTime = er.Event.EndDateTime;
			e.ceName = ce.Name; // ContactEncounter Name
            e.ceDuration = ce.EncounterDuration; // ContactEncounter duration (= Event Duration)
            impactedEvents.add(e);
        }

        /**
         * Insert ContactEncounter records from the group Events 
         **/
		try {
        	insert newContactEncounters;
		} catch(DmlException e) {
    		System.debug('The following exception has occurred: ' + e.getMessage());
		}

		/**
		 * Get a list of affected peer Employees (Users) so that we can bulk look up their Contact records
         *  These peers could be either Event Owners or Event participants (Relations)
         *  The Contact Ids are needed within a loop below.  This is to avoid individual SOQL statements within that loop.
         *  This relies on User.EmployeeNumber being available for each User
		 **/
        list<String> potentialPeerENums = new List<String>();
        for (EventRelation er : [SELECT Id,
                                    TYPEOF Event.Owner
                                        WHEN User THEN EmployeeNumber
                                    END,
                                    TYPEOF Relation
                                        WHEN User THEN EmployeeNumber
                                    END 
                                    FROM EventRelation 
                                    WHERE Relation.Type = 'User' AND Event.IsGroupEvent = TRUE AND EventId IN :impactedEventIds]) { 
            // Add the owner and participant (Relation) to the list of Employee Numbers
            if (er.Event.Owner instanceof User) {
                User userOwner = er.Event.Owner;
                if (userOwner.EmployeeNumber != null) {
                    potentialPeerENums.add(userOwner.EmployeeNumber);
                }
            }
            if (er.Relation instanceof User) {
                User userRelated = er.Relation;
                if (userRelated.EmployeeNumber != null) {
                    potentialPeerENums.add(userRelated.EmployeeNumber);
                }
            }
        }
         // Get the list of Contacts from the Employee Numbers
		List<Contact> potentialPeers = [SELECT Id,HealthCloudGA__SourceSystemId__c FROM Contact WHERE HealthCloudGA__SourceSystemId__c IN :potentialPeerENums];

		/**
		 *  Get all employees (Users) sharing Events with the affected employee (User)
		 *  TO DO: Consider duplicate prevention when the same peer attends multiple Events with the affected employee (User)
         *  TO DO: Determine if this works properly with recurring Events (start/end date added to query to attempt to narrow)
         *  TO DO: Provide option to only include Users who did not decline the invite (Status != 'Declined')
		 **/
        List<ContactEncounterParticipant> newCEParticipants = new List<ContactEncounterParticipant>();
        // Loop through each Event
        for (ceClass ce : impactedEvents) {
            // Create a list of Event participant Ids for this Event that we've already collected to avoid duplicates
            List<Id> capturedParticipantIds = new List<Id>();

            // For this Event get all event owners and attendees (Relations)
            for (EventRelation er : [SELECT Id,RelationId,EventId,Event.Subject,Event.ActivityDateTime,
                                        TYPEOF Event.Owner
                                            WHEN User THEN Id,EmployeeNumber
                                        END,
                                        TYPEOF Relation
                                            WHEN User THEN EmployeeNumber
                                        END
                                        FROM EventRelation 
                                        WHERE EventId = :ce.eId AND Relation.Type = 'User' AND Event.IsGroupEvent = TRUE AND Event.ActivityDate >= :inputVars[0].startDate AND Event.ActivityDate <= :inputVars[0].endDate]) {

                // Generate a list of ContactEncounterParticipants (affected Employees) 
                //  This includes both the owner and participant (Relation) where both have the same ContactEncounterId
                //  Track which Event participants have already been captured to prevent duplicate entries when the affected employee is the Event owner
                ContactEncounterParticipant p1 = new ContactEncounterParticipant();
                String thisEncounterName = 'Calendar Event: ' + er.Event.Subject + ' on ' + er.Event.ActivityDateTime;
                p1.ContactEncounterId = getCEIdfromName(newContactEncounters,thisEncounterName);
                if (er.Event.Owner instanceof User) {
                    User userOwner = er.Event.Owner;
                    if (!capturedParticipantIds.contains(er.Event.Owner.Id) && userOwner.EmployeeNumber != null) {
                        p1.ContactId = getCIdfromENum(potentialPeers,userOwner.EmployeeNumber);
                        capturedParticipantIds.add(er.Event.Owner.Id);
                    }
                }
                newCEParticipants.add(p1);
                ContactEncounterParticipant p2 = new ContactEncounterParticipant();
                p2.ContactEncounterId = p1.ContactEncounterId;
                if (er.Relation instanceof User) {
                    User userRelated = er.Relation;
                    if (userRelated.EmployeeNumber != null) {
                        p2.ContactId = getCIdfromENum(potentialPeers,userRelated.EmployeeNumber);
                    }
                }
                newCEParticipants.add(p2);
            }
        }
        /**
         * Insert ContactEncounterParticipant records for the previously inserted ContactEncounters 
         **/
		try {
        	insert newCEParticipants;
		} catch(DmlException e) {
    		System.debug('The following exception has occurred: ' + e.getMessage());
		}

        // TEST
        System.debug(impactedEvents);
        System.debug(newContactEncounters);
        System.debug(potentialPeerENums);
        System.debug(newCEParticipants);
//        delete newContactEncounters;
    }
}