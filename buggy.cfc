<cfcomponent extends="rhino_core.packages.applet">

	<!---
		Buggy is a bug tracking, issue and task management plugin for the cfRhino framework
		
		Devised as a single CFC that does 'the lot' it ended up using a number of external
		files to help keep things a little simpler, however, in essence, the business logic
		is all encapsulated into a single CFC.
		
		Handles many of the things you'd expect:
			- multiple users
			- multiple products
			- variety of issue 'types'
			- knowledge base
			- feature requests
			- statistics for admins
			- search
	--->

	<cfset variables.pages = {}>
    <cfset variables.wf_states = ["Raise a bug", "Accepted", "More Information", "Resolved", "Closed"]>
    <cfset variables.wf_transitions = ["accept", "duplicate", "as-design", "request-for-more-info", "resolve", "close"]>
	
	<!--- setup the data storage --->
	<cfset variables.xml_products = "<?xml version=""1.0"" encoding=""utf-8""?><products></products>">
	<cfset variables.xml_issues   = "<?xml version=""1.0"" encoding=""utf-8""?><issues></issues>">
	<cfset variables.xml_history  = "<?xml version=""1.0"" encoding=""utf-8""?><history></history>">
	<cfset variables.xml_users    = "<?xml version=""1.0"" encoding=""utf-8""?><users></users>">

    <cffunction name="init" access="public" output="false">
		<cfset var thisRoot = GetDirectoryFromPath(GetCurrentTemplatePath())>
		<cfset var jsonFile = thisRoot & "buggy.json">
		<cfset super.init()>
		
		<!--- load the app descriptor from json --->
		<cfif FileExists(jsonFile)>
			<cffile action="read" file="#jsonFile#" variable="jsonData">
			<cfset variables.pages = DeserializeJson(jsonData)>
		</cfif>
		
		<!--- load the data files --->
		<cfset getDataFiles(thisRoot)>
		
		<cfset this.setScope("appextension")>
	</cffunction>
    
	<cffunction name="interceptLayout" access="public" hint="declared to allow this module to intercept page requests directed at it">
		<!--- this function needs to exist in order for the framework to allow it to catch onRequestPageUndefined events --->
	</cffunction>

	<!--- this function is called when page.cfc cannot find the requested page in the parsed XML definitions --->
	<cffunction name="onRequestPageUndefined" access="public">
        <cfset var pageData = getBasicPage()>
		<cfset var pageName = "">
		
		<!--- if the requested layout is longer than 1 item and the item exists in the pages struct, set it up --->
		<cfif ListLen(request.layout, ".") GTE 2>
			<cfset pageName = ListDeleteAt(request.layout, 1, ".")>
			<cfif StructKeyExists(variables.pages, pageName)>
				<cfset StructAppend(pageData, variables.pages[pageName])>
				<cfreturn pageData>
			</cfif>
		</cfif>
		
		<!--- if the extension doesn't handle the requested layout, do the default --->
		<cfset request.rhino.getLog().addEntry("[extension:buggy] Unable to handle '#request.layout#'", 3)>
		<cfreturn super.onRequestPageUndefined()>
	</cffunction>
    
    <!--- render most of the pages...
		1.	Projects
		2.	Bugs/Project
		3.	Bug details
		4.	Bug submit
	
	Workflow
		s1.	Raise a bug:
			a1	accept (reproducable) (s2)
			a2	duplicate (note dupe no.) (s4)
			a3	as-design (s4)
			a4	request-for-more-info (s3)
		s2.	Accepted:
			a5	resolved (s4)
			a6	close (s5)
			a3	as-designed (s4)
		s3.	More information required from the client
		s4.	Resolved -> timed out (5), confirmed (5), 
		s5.	Closed
	--->
	
	<cffunction name="getHead">
		<cfreturn "<h1>Buggy <span class='in-head-tagline'>Simple Issue Tracking</span></h1>">
	</cffunction>
	
	<cffunction name="getNav">
		<cfset var navContent = "">
		<cfsavecontent variable="navContent">		<ul>
			<li>All Products</li>
			<li>All Issues</li>
			<li>Search Issues</li>
			<li>My Issues</li>
			<li><a href="./?layout=buggy.issue&amp;issueid=dhs8Esajdg&amp;dotnet=true">An Issue</a></li>
		</ul></cfsavecontent>
		<cfreturn navContent>
	</cffunction>
	
	<cffunction name="getTitle">
		<cfset var title = "Buggy - Issue Tracking">
		<cfset var pageName = ListDeleteAt(request.layout, 1, ".")>
		<cfif StructKeyExists(variables.pages, pageName) AND StructKeyExists(variables.pages[pageName], "pagetitle")>
			<cfset title = "#variables.pages[pageName].pagetitle#">
		</cfif>
		<cfreturn title>
	</cffunction>
	
	<cffunction name="getHome">
		<cfreturn "<h3>My Home</h3>">
	</cffunction>
	
	<cffunction name="dspIssue">
		<cfset var content = "">
		
		<cfif StructKeyExists(url, "issueid")>
			<cfset issueData = getIssue(url.issueid)>
			<cfsavecontent variable="content"><table width="100%">
				<tr>
					<td>Title</td>
					<td>Created</td>
					<td>Creator</td>
					<td>Updated</td>
				</tr>
				<tr><cfoutput>
					<td>#issueData.title#</td>
					<td>#issueData.created#</td>
					<td>#issueData.creator#</td>
					<td>#issueData.lastUpdated#</td>
				</cfoutput></tr>
			</table></cfsavecontent>
		</cfif>
							  
		<cfreturn content>
	</cffunction>
	
	
	
	<!---
		provide the model
	--->
	
	<!--- load the XML files that contain the data --->
	<cffunction name="getDataFiles" access="private" output="false">
		<cfargument name="thisRoot" type="string" required="true">
		<cfset var productsFile = thisRoot & "data/products.xml">
		<cfset var issuesFile   = thisRoot & "data/issues.xml">
		<cfset var historyFile  = thisRoot & "data/hitory.xml">
		<cfset var usersFile    = thisRoot & "data/users.xml">

		<!--- products --->
		<cfif NOT FileExists(productsFile)><cffile action="write" file="#productsFile#" charset="utf-8" output="#variables.xml_products#"></cfif>
		<cffile action="read" file="#productsFile#" variable="variables.xml_products">
		<cfset xml_products = XmlParse(xml_products)>

		<!--- issues --->
		<cfif NOT FileExists(issuesFile)><cffile action="write" file="#issuesFile#" charset="utf-8" output="#variables.xml_issues#"></cfif>
		<cffile action="read" file="#issuesFile#" variable="variables.xml_issues">
		<cfset xml_issues = XmlParse(xml_issues)>

		<!--- history --->
		<cfif NOT FileExists(historyFile)><cffile action="write" file="#historyFile#" charset="utf-8" output="#variables.xml_history#"></cfif>
		<cffile action="read" file="#historyFile#" variable="variables.xml_history">
		
		<!--- issues --->
		<cfif NOT FileExists(usersFile)><cffile action="write" file="#usersFile#" charset="utf-8" output="#variables.xml_users#"></cfif>
		<cffile action="read" file="#usersFile#" variable="variables.xml_users">
	</cffunction>
	
	<!--- find an issue with a matching id --->
	<cffunction name="getIssue" access="private" returntype="query" output="false">
		<cfargument name="issueId" type="any" required="true">
		
		<cfset var issueDetail = QueryNew("title,created,creator,lastUpdated")>
		<cfset var res = ArrayNew(1)>
		
		<cfset res = XmlSearch(xml_issues, "issues/issue[@id='#issueId#']")>
		<cfif ArrayLen(res) EQ 1>
			<cfset QueryAddRow(issueDetail, 1)>
			<cfset QuerySetCell(issueDetail, "title", res[1].title.xmlText)>
			<cfset QuerySetCell(issueDetail, "created", res[1].created.xmlText)>
			<cfset QuerySetCell(issueDetail, "creator", res[1].created_by.xmlText)>
			<cfset QuerySetCell(issueDetail, "lastUpdated", "2011-12-12T14:31:00Z-08:00")>
		</cfif>
		
		<cfreturn issueDetail>
	</cffunction>
	
	
	
	<cffunction name="getBasicPage" access="private" returntype="struct" output="false" hint="returns a basic page struct that can be modified for a particular response">
		<cfset var tempData = StructNew()>
		<cfscript>
		tempData.layouts = arrayNew(1);
		tempData.layouts[1] = "lyt_buggy";
		tempData.datasets = arrayNew(1);
		tempData.modules = structNew();
		tempData.space = structNew();
		tempData.pagelets = structNew();
		tempData.spacePagelets = structNew();
		tempData.params = structNew();
		tempData.head = structNew();
		tempData.scope = getScope();
		tempData.handler = "page";
		// tempData.interceptScope = "application"; // determines where to look for assets without a prefix.
		</cfscript>
		<cfreturn tempData>
	</cffunction>

</cfcomponent>