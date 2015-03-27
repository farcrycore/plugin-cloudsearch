<cfsetting enablecfoutputonly="true">

<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />
<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />

<cfparam name="form.searchtype" default="" />
<cfparam name="form.text" default="" />

<skin:loadJS id="fc-jquery" />
<skin:loadJS id="formatjson" />
<skin:loadJS id="fc-bootstrap" />

<skin:htmlHead><cfoutput>
	<style>
		##message-log td, ##message-log th { 
			padding: 5px; 
		}
		##message-log .this-item td {
			background-color: ##dff0d8;
		}
		##message-log .related-item td {
			background-color: ##fcf8e3;
		}
		.formatjson .key {
			color:##a020f0;
		}
		.formatjson .number {
			color:##ff0000;
		}
		.formatjson .string {
			color:##000000;
		}
		.formatjson .boolean {
			color:##ffa500;
		}
		.formatjson .null {
			color:##0000ff;
		}
	</style>
</cfoutput></skin:htmlHead>

<ft:processform action="Search">
	<cfset stArgs = {} />
	<cfif len(form.searchtype)>
		<cfset stArgs["typename"] = form.searchtype />
	</cfif>
	<cfif len(form.text)>
		<cfset stArgs["conditions"] = [{ "text"=form.text }] />
	</cfif>
	<cfset stSearch = application.fc.lib.cloudsearch.search(argumentCollection=stArgs) />
</ft:processform>

<cfset qContentTypes = application.fapi.getContentObjects(typename="csContentType", lProperties="contentType", orderby="contentType") />

<cfoutput>
	<h1>Search</h1>
</cfoutput>

<ft:form>
	<ft:field label="Content Type">
		<cfoutput>
			<select name="searchtype" multiple="true">
				<option value="" <cfif form.searchtype eq "">selected</cfif>>All</option>
				<cfloop query="qContentTypes">
					<option value="#qContentTypes.contentType#" <cfif form.searchtype eq qContentTypes.contentType>selected</cfif>>#application.stCOAPI[qContentTypes.contentType].displayname#</option>
				</cfloop>
			</select>
		</cfoutput>
	</ft:field>

	<ft:field label="Text Search">
		<cfoutput><input type="text" name="text" value="#form.text#"></cfoutput>
	</ft:field>

	<ft:buttonPanel>
		<ft:button value="Search" />
	</ft:buttonPanel>
</ft:form>

<cfif isDefined("stSearch")>
	<cfif structKeyExists(stSearch,"conditions")>
		<cfset stSearch.jsonConditions = application.fapi.formatJSON(serializeJSON(stSearch.conditions)) />
	</cfif>

	<cfoutput>
		<div class="tabbable"> <!-- Only required for left/right tabs -->
			<ul class="nav nav-tabs">
				<cfif structKeyExists(stSearch,"conditions")>
					<li><a href="##conditions">Query - CFML</a></li>
				</cfif>
				<li><a href="##raw">Query - Raw</a></li>
				<li class="active"><a href="##items">Result - Items</a></li>
				<li><a href="##facets">Result - Facets</a></li>
			</ul>

			<div class="tab-content">
				<cfif structKeyExists(stSearch,"conditions")>
					<div id="conditions" class="tab-pane">
						<pre class="formatjson">#stSearch.jsonConditions#</pre>
					</div>
				</cfif>

				<div id="raw" class="tab-pane">
					<pre>#stSearch.query#</pre>
				</div>

				<div id="items" class="tab-pane active">
					<table class="table table-striped">
						<thead>
							<tr>
								<th>Object ID</th>
								<th>Typename</th>
								<th>Label</th>
								<th></th>
							</tr>
						</thead>
						<tbody>
							<cfloop query="stSearch.items">
								<cfset stObject = application.fapi.getContentObject(typename=stSearch.items.typename,objectid=stSearch.items.objectid) />

								<tr>
									<td>#stSearch.items.objectid#</td>
									<td>#stSearch.items.typename#</td>
									<td>#stObject.label#</td>
									<td><a title="#application.stCOAPI[stSearch.items.typename].displayname# Overview" onclick="$fc.objectAdminAction('Media Overview', this.href, { onHidden : function(){} }); return false;" href="#application.url.webtop#/edittabOverview.cfm?typename=#stSearch.items.typename#&method=edit&ref=iframe&objectid=#stSearch.items.objectid#&dialogID=fcModal">Overview</a></td>
								</tr>
							</cfloop>
							<cfif stSearch.items.recordcount eq 0>
								<tr>
									<td colspan="2">No items returned</td>
								</tr>
							</cfif>
						</tbody>
					</table>
				</div>

				<div id="facets" class="tab-pane">
					<table class="table table-striped">
						<thead>
							<tr>
								<th>Field</th>
								<th>Value</th>
								<th>Count</th>
							</tr>
						</thead>
						<tbody>
							<cfloop query="stSearch.facets">
								<tr>
									<td>#stSearch.facets.field#</td>
									<td>#stSearch.facets.value#</td>
									<td>#stSearch.facets.count#</td>
								</tr>
							</cfloop>
							<cfif stSearch.facets.recordcount eq 0>
								<tr>
									<td colspan="3">No facets returned</td>
								</tr>
							</cfif>
						</tbody>
					</table>
				</div>
			</div>
		</div>
		<script>
			$j(document).on("click",'.tabbable a', function (e) {
				e.preventDefault();
				$j(this).tab('show');
			});
		</script>
	</cfoutput>
</cfif>

<cfsetting enablecfoutputonly="false">