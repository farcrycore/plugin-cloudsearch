<cfcomponent extends="farcry.core.packages.forms.forms" key="cloudsearch" displayname="CloudSearch" hint="AWS CloudSearch settings">

	<cfproperty name="domain" type="string" required="false"
		ftSeq="1" ftWizardStep="" ftFieldset="" ftLabel="Domain Name">

	<cfproperty name="region" type="string" required="false"
		ftSeq="2" ftWizardStep="" ftFieldset="" ftLabel="Region">

	<cfproperty name="accessID" type="string" required="false"
		ftSeq="3" ftWizardStep="" ftFieldset="" ftLabel="Access ID">

	<cfproperty name="accessSecret" type="string" required="false"
		ftSeq="4" ftWizardStep="" ftFieldset="" ftLabel="Access Secret">

</cfcomponent>