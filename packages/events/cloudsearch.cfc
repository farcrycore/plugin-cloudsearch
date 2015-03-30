<cfcomponent displayname="Archive" hint="Content archive functionality" output="false" component="fcTypes">
	
	<!--- The basic rule is: if publicly visible content is changed, archive first --->
	

	<cffunction name="saved" access="public" output="false" hint="Invoked immediately before DB is updated">
		<cfargument name="typename" type="string" required="true" hint="The type of the object" />
		<cfargument name="oType" type="any" required="true" hint="A CFC instance of the object type" />
		<cfargument name="stProperties" type="struct" required="true" hint="The object" />
		<cfargument name="user" type="string" required="true" />
		<cfargument name="auditNote" type="string" required="true" />
		<cfargument name="bSessionOnly" type="boolean" required="true" />
		
		<cfset var stProps = duplicate(arguments.stProperties) />
		<cfset var lastupdatedby = "">
		<cfset var st = {} />

		<!--- do nothing while update app is happening --->
		<cfif NOT isDefined("application.bInit") OR application.bInit eq false>
			<cfreturn />
		</cfif>
		
		<!--- do nothing if it's a session-only update --->
		<cfif arguments.bSessionOnly>
			<cfreturn />
		</cfif>
		
		<cfset st = application.fc.lib.cloudsearch.getTypeIndexFields(arguments.typename) />

		<!--- update index --->
		<cfif not structIsEmpty(st)>
			<cfset application.fapi.getContentType("csContentType").importIntoCloudSearch(stObject=arguments.stProperties, operation="updated") />
		</cfif>
	</cffunction>
	
	<cffunction name="deleted" access="public" hint="I am invoked when a content object has been deleted">
		<cfargument name="typename" type="string" required="true" hint="The type of the object" />
		<cfargument name="oType" type="any" required="true" hint="A CFC instance of the object type" />
		<cfargument name="stObject" type="struct" required="true" hint="The object" />
		<cfargument name="user" type="string" required="true" />
		<cfargument name="auditNote" type="string" required="true" />
		
		<cfset var st = application.fc.lib.cloudsearch.getTypeIndexFields(arguments.typename) />

		<cfif not structIsEmpty(st)>
			<cfset application.fapi.getContentType("csContentType").importIntoCloudSearch(stObject=arguments.stProperties, operation="deleted") />
		</cfif>
	</cffunction>
	
</cfcomponent>