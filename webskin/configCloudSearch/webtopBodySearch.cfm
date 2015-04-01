<cfsetting enablecfoutputonly="true">

<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />
<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />

<cfparam name="form.history" default="" />
<cfparam name="form.searchtype" default="" />
<cfparam name="form.text" default="" />
<cfparam name="form.conditions" default="" />
<cfparam name="form.filters" default="" />
<cfparam name="form.rawQuery" default="" />
<cfparam name="form.rawFilter" default="" />

<skin:loadJS id="fc-jquery" />
<skin:loadJS id="formatjson" />
<skin:loadJS id="fc-bootstrap" />

<skin:loadJS baseHREF="/farcry/plugins/cloudsearch/www/codemirror/" lFiles="codemirror.js,javascript.js" />
<skin:loadCSS baseHREF="/farcry/plugins/cloudsearch/www/codemirror/" lFiles="codemirror.css" />
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

<cfset queryTab = "basic" />

<ft:processform action="Search Basic">
	<cfset stArgs = {} />
	<cfif len(form.searchtype)>
		<cfset stArgs["typename"] = form.searchtype />
	</cfif>
	<cfif len(form.text)>
		<cfset stArgs["conditions"] = [{ "text"=form.text }] />
	</cfif>
	<cfset stSearch = application.fc.lib.cloudsearch.search(argumentCollection=stArgs) />
	<cfif structKeyExists(stSearch,"conditions")>
		<cfset form.conditions = application.fapi.formatJSON(serializeJSON(stSearch.conditions)) />
	</cfif>
	<cfset form.rawQuery = stSearch.rawQuery />
	<cfif structKeyExists(stSearch,"filters")>
		<cfset form.filters = application.fapi.formatJSON(serializeJSON(stSearch.filters)) />
	</cfif>
	<cfset form.rawFilter = stSearch.rawFilter />
	<cfset form.history = 1 />

	<cfset queryTab = "basic" />
</ft:processform>

<ft:processform action="Search History">
	<cfset form.history = form.SelectedObjectID />

	<cfset aSearchLog = application.fc.lib.cloudsearch.getSearchLog() />
	<cfset searchLog = aSearchLog[form.history] />
	<cfset stSearch = application.fc.lib.cloudsearch.search(argumentCollection=searchLog.args) />
	<cfset form.searchtype = "" />
	<cfset form.text = "" />
	<cfif structKeyExists(stSearch,"conditions")>
		<cfset form.conditions = application.fapi.formatJSON(serializeJSON(stSearch.conditions)) />
	</cfif>
	<cfset form.rawQuery = stSearch.rawQuery />
	<cfif structKeyExists(stSearch,"filters")>
		<cfset form.filters = application.fapi.formatJSON(serializeJSON(stSearch.filters)) />
	</cfif>
	<cfset form.rawFilter = stSearch.rawFilter />

	<cfset queryTab = "history" />
</ft:processform>

<ft:processform action="Search Conditions">
	<cfif isJSON(form.conditions)>
		<cfset stSearch = application.fc.lib.cloudsearch.search(conditions=deserializeJSON(form.conditions)) />
		<cfset form.searchtype = "" />
		<cfset form.text = "" />
		<cfset form.conditions = application.fapi.formatJSON(serializeJSON(stSearch.conditions)) />
		<cfset form.rawQuery = stSearch.rawQuery />
		<cfset form.filters = application.fapi.formatJSON(serializeJSON(stSearch.filters)) />
		<cfset form.rawFilter = stSearch.rawFilter />
		<cfset form.history = 1 />
	<cfelse>
		<skin:bubble tags="error" message="Invalid conditions JSON" />
	</cfif>

	<cfset queryTab = "conditions" />
</ft:processform>

<ft:processform action="Search Raw">
	<cfset stSearch = application.fc.lib.cloudsearch.search(rawQuery=form.rawQuery,rawFilter=form.rawFilter) />
	<cfset form.searchtype = "" />
	<cfset form.text = "" />
	<cfset form.conditions = "" />
	<cfset form.rawQuery = stSearch.rawQuery />
	<cfset form.filters = "" />
	<cfset form.rawFilter = stSearch.rawFilter />
	<cfset form.history = 1 />

	<cfset queryTab = "raw" />
</ft:processform>

<cfset qContentTypes = application.fapi.getContentObjects(typename="csContentType", lProperties="contentType", orderby="contentType") />
<cfset aSearchLog = application.fc.lib.cloudsearch.getSearchLog() />

<cfoutput>
	<h1>Search</h1>
</cfoutput>

<ft:form>
	<cfoutput>
		<div class="tabbable"> <!-- Only required for left/right tabs -->
			<ul class="nav nav-tabs">
				<li class="<cfif queryTab eq 'basic'>active</cfif>"><a href="##search-basic">Basic</a></li>
				<li class="<cfif queryTab eq 'history'>active</cfif>"><a href="##search-history">History</a></li>
				<li class="<cfif queryTab eq 'conditions'>active</cfif>"><a href="##search-conditions">Conditions</a></li>
				<li class="<cfif queryTab eq 'raw'>active</cfif>"><a href="##search-raw">Raw Query</a></li>
			</ul>

			<div class="tab-content">
				<div id="search-basic" class="<cfif queryTab eq 'basic'>active</cfif> tab-pane">
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
						<ft:button value="Search Basic" text="Search" />
					</ft:buttonPanel>
				</div>

				<div id="search-history" class="<cfif queryTab eq 'history'>active</cfif> tab-pane">
					<div style="height:150px; overflow-y:scroll;">
						<cfset prev = "" />
						<cfloop from="1" to="#arraylen(aSearchLog)#" index="i">
							<cfset searchLog = aSearchLog[i] />

							<cfif prev neq serializeJSON(searchLog.args) and (structKeyExists(searchLog.args,"typename") or structKeyExists(searchLog.args,"rawQuery") or structKeyExists(searchLog.args,"conditions"))>
								<div class="row" style="margin-bottom:10px; margin-left:10px; margin-right:10px; border-bottom:1px solid ##CCC; <cfif form.history eq i>background-color:##f9e6d4;</cfif>">
									<span class="span2" style="padding:10px;">#timeformat(searchLog.timestamp,'hh:mmtt')# #dateformat(searchLog.timestamp,'d mmm yyyy')#</span>

									<span class="span9" style="padding:10px;">
										<cfif structKeyExists(searchLog.args,"typename")>
											<strong>Types</strong>:
											<cfloop from="1" to="#listlen(searchLog.args.typename)#" index="thistype">
												#application.stCOAPI[listgetat(searchLog.args.typename,thistype)].displayname#<cfif thistype neq listlen(searchLog.args.typename)>, </cfif>
											</cfloop>
											<br>
										</cfif>

										<cfif structKeyExists(searchLog.args,"rawQuery")>
											<strong>Raw Query</strong>: <code>#searchLog.args.rawQuery#</code>
											<br>
										</cfif>

										<cfif structKeyExists(searchLog.args,"conditions")>
											<strong>Conditions</strong>: <code class="formatjson">#serializeJSON(searchLog.args.conditions)#</code>
											<br>
										</cfif>

										<cfif structKeyExists(searchLog.args,"rawFilter")>
											<strong>Raw Filter</strong>: <code>#searchLog.args.rawFilter#</code>
											<br>
										</cfif>

										<cfif structKeyExists(searchLog.args,"filters")>
											<strong>Filter</strong>: <code class="formatjson">#serializeJSON(searchLog.args.filters)#</code>
											<br>
										</cfif>
									</span>

									<span class="span1" style="padding:10px;">
										<ft:button value="Search History" text="Run" SelectedObjectID="#i#" />
									</span>
								</div>

								<cfset prev = serializeJSON(searchLog.args) />
							</cfif>
						</cfloop>
					</div>
				</div>

				<div id="search-conditions" class="<cfif queryTab eq 'conditions'>active</cfif> tab-pane">
					<textarea id="conditions-search" name="conditions" class="span12" rows="5">#form.conditions#</textarea>
					<script>
						window.conditionsCodeMirror = CodeMirror.fromTextArea(document.getElementById("conditions-search",{"mode":"json"}));
						$j("a[href='##search-conditions']").on("shown",function(){
							window.conditionsCodeMirror.refresh();
						});
					</script>

					<textarea id="filters-search" name="filters" class="span12" rows="5">#form.filters#</textarea>
					<script>
						window.filtersCodeMirror = CodeMirror.fromTextArea(document.getElementById("filters-search",{"mode":"json"}));
						$j("a[href='##search-filters']").on("shown",function(){
							window.filtersCodeMirror.refresh();
						});
					</script>

					<ft:buttonPanel>
						<ft:button value="Search Conditions" text="Search" />
					</ft:buttonPanel>
				</div>

				<div id="search-raw" class="<cfif queryTab eq 'raw'>active</cfif> tab-pane">
					<textarea id="raw-search-conditions" name="rawQuery" class="span12" rows="5">#form.rawQuery#</textarea>
					<textarea id="raw-search-filters" name="rawFilter" class="span12" rows="5">#form.rawFilter#</textarea>
					
					<ft:buttonPanel>
						<ft:button value="Search Raw" text="Search" />
					</ft:buttonPanel>
				</div>
			</div>
		</div>
	</cfoutput>

</ft:form>

<cfif isDefined("stSearch")>
	<h1>Results</h1>
	<cfif structKeyExists(stSearch,"conditions")>
		<cfset stSearch.jsonConditions = application.fapi.formatJSON(serializeJSON(stSearch.conditions)) />
	</cfif>
	<cfif structKeyExists(stSearch,"filters")>
		<cfset stSearch.jsonFilters = application.fapi.formatJSON(serializeJSON(stSearch.filters)) />
	</cfif>

	<cfoutput>
		<div class="tabbable"> <!-- Only required for left/right tabs -->
			<ul class="nav nav-tabs">
				<cfif structKeyExists(stSearch,"conditions")>
					<li><a href="##results-conditions">Query - Conditions</a></li>
				</cfif>
				<li><a href="##results-raw">Query - Raw</a></li>
				<li class="active"><a href="##results-items">Result - Items</a></li>
				<li><a href="##results-facets">Result - Facets</a></li>
			</ul>

			<div class="tab-content">
				<cfif structKeyExists(stSearch,"conditions")>
					<div id="results-conditions" class="tab-pane">
						<pre class="formatjson">#stSearch.jsonConditions#</pre>
						<pre class="formatjson">#stSearch.jsonFilters#</pre>
					</div>
				</cfif>

				<div id="results-raw" class="tab-pane">
					<pre>#stSearch.rawQuery#</pre>
					<pre>#stSearch.rawFilter#</pre>
				</div>

				<div id="results-items" class="tab-pane active">
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

				<div id="results-facets" class="tab-pane">
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
	</cfoutput>
</cfif>

<cfoutput>
	<script>
		$j(document).on("click",'.farcry-main .nav-tabs a', function (e) {
			e.preventDefault();
			$j(this).tab('show');
		});
	</script>
</cfoutput>

<cfsetting enablecfoutputonly="false">