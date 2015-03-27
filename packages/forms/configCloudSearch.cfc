<cfcomponent extends="farcry.core.packages.forms.forms" key="cloudsearch" displayname="CloudSearch" hint="AWS CloudSearch settings">

	<cfproperty name="domain" type="string" required="false"
		ftSeq="1" ftWizardStep="" ftFieldset="AWS" ftLabel="Domain Name">

	<cfproperty name="region" type="string" required="false"
		ftSeq="2" ftWizardStep="" ftFieldset="AWS" ftLabel="Region">

	<cfproperty name="accessID" type="string" required="false"
		ftSeq="3" ftWizardStep="" ftFieldset="AWS" ftLabel="Access ID">

	<cfproperty name="accessSecret" type="string" required="false"
		ftSeq="4" ftWizardStep="" ftFieldset="AWS" ftLabel="Access Secret">


	<cfproperty name="batchSize" type="integer" required="false" ftDefault="-1"
		ftSeq="11" ftWizardStep="" ftFieldset="Scheduled Task" ftLabel="Batch Size"
		ftHint="Number of documents to update in a single batch. Default (-1) is to update up to 5mb of data at a time, as recommended by AWS.">

	<cfproperty name="bSelfQueuing" type="boolean" required="false" ftDefault="true"
		ftSeq="12" ftWizardStep="" ftFieldset="Scheduled Task" ftLabel="Self Queuing"
		ftHint="Disable if you want to set an interval and end date on the scheduled task. By default it will queue itself as long as there are more records to update in the index, then stop.">

</cfcomponent>