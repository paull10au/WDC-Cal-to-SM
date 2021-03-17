# WDC-Cal-to-SM
Salesforce Calendar to Work.com Contact Tracing

<a style="margin-right: 40%;" href="https://deploy-to-sfdx.com">
  <img align="right" alt="Deploy using SFDX"
       src="https://deploy-to-sfdx.com/dist/assets/images/DeployToSFDX.svg">
</a>

Salesforce Work.com offers several solutions, two of which are:
1) Manual Contact Tracing which allows contact tracers to enter encounters and participants
2) Calendaring including options to synchronize w/ Outlook/Google calendars

This tool links the two. When employees attended the same meeting(s), a contact tracer can choose to import those calendar events and the co-workers in them as Contact Encounters and Contact Encounter Participants in Contact Tracing.

## Installation
1. Ensure your Work.com org correctly has functionality turned on to sync User > Individual > Employee > Person Account as follows:
    1. User records employees you intend to contact trace have the EmployeeNumber field populated
    2. Work.com [b2w_UserTrigger](https://help.salesforce.com/articleView?id=wcc_setup_understand_disable_wcc.htm&type=5) which keeps User and Individual records in sync given that the User record is populated with an EmployeeNumber.
    3. Work.com's [b2w_EmployeeTrigger](https://help.salesforce.com/articleView?id=wcc_setup_understand_disable_wcc.htm&type=5) which syncs the Individual record to the Employee record
    4. Contact Tracing for Employees is configured to sync the Employee object to the Person Account object as [described here](https://help.salesforce.com/articleView?id=emergency_response_admin_synchronize_apex.htm&type=5)
Salesforce Calendaring uses Event and EventRelation objects to attach Attendee User records to Events.
2. Install the components from this Github repository in your Salesforce Work.com Org
3. Add the Lightning Component to the Contact Tracing page layout:
    1. Navigate to a Contact Tracing record
    2. Click Setup > Edit Page
    3. Drag a Flow component onto the page layout
    4. Set the Flow for the component to "Load Calendar for Contact Tracing"
    5. Check the box under the contactTraceRecordID input value to "Pass Record ID into this variable" (You can leave all other input variables blank)
    6. Save the page layout and exit the Lightning app builder
4. Configure syncrhonization of Users' Outlook or Google Calendars to Salesforce Events with tools such as Einstein Activity Capture, Salesforce Inbox, Lightning Sync, or tools from ISV providers such as Riva.  Syncrhonization should be configured to ensure the Event Attendees functionality is used.  Details for Lightning Sync can be found [here](https://help.salesforce.com/articleView?id=lightning_sync_admin_event_attendee_sync.htm&type=5) 

## Usage Instructions
1. Navigate to a Contact Tracing record
2. In the "Load Calendar for Contact Tracing" component you added to the page, optionally update the Start/End Dates. All meetings with multiple Attendees between these two dates will be pulled into Contact Tracing.
3. Click "Next". This will perform all of the record creation
4. Optionally click "Finish"
5. Refresh the page and you will see any added contact tracing linkages

## Reset Instructions
If you want to clear out all of the ContactEncounters and (child) ContactEncounterParticipant records from your org that were added by this component, run the following in the Developer Console > Debug > Open Execute Anonymous Window:

    List<ContactEncounter> ce = [SELECT Id FROM ContactEncounter WHERE Name LIKE 'Calendar Event: %'];
    delete ce;

## Notes
* If you click the demo component a second time, records will be duplicated and you'll have twice as many
* Duplicates on Graph: If the same peer employee attended multiple meetings with the affected employee, they will be added multiple times against multiple encounters. This mirrors how the Contact Tracing UI works if an Employee is interviewed as having been with the same person during multiple encounters. However, it causes the graph to show the same employee multiple times. (Use this VOC if this visualization oddity impacts your opportunities.)
