<!DOCTYPE html>
<html>
<head>
<title><cfoutput>#getAsset("buggy.getTitle", "appextfunction")#</cfoutput></title>
<meta http-equiv="Expires" content="Tue, 10 May 1999 15:00:00 GMT"/>
<meta http-equiv="Pragma" content="no-cache"/>
<meta http-equiv="Cache-Control" content="no cache"/>
<link href="/styles/buggy.css" rel="stylesheet" type="text/css" />
<link rel="icon" type="image/png" href="favicon.ico">
<meta name="requestlayout" content="#request.layout#"/>
<style>

</style>
</head>
<body>

<cfoutput><div id="allcontent">

	<div id="masthead">
		#getSpace("head")#
	</div>
	
	<nav id="primary-nav">
		#getSpace("menu")#
	</nav>
	
	<div id="main-content">
		<h1 class="topelem">#getAsset("buggy.getTitle", "appextfunction")#</h1>
		#getSpace("content")#
	</div>
	
</div></cfoutput>

</body>
</html>