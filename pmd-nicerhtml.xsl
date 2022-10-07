<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:pmd="http://pmd.sourceforge.net/report/2.0.0">
	<xsl:output method="xml" indent="yes" doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN" doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd" />
	<xsl:decimal-format decimal-separator="." grouping-separator="," />

	<!-- keys for violations list -->
	<xsl:key name="violations" match="pmd:violation" use="@rule" />

	<!-- XSL for CICD report. Author : Thomas Prouvot. -->
	<!-- Inspired by Checkstyle -->


	<xsl:template match="pmd:pmd">
		<!--** Process root node pmd : html header, style, call templates -->
		<html>
			<head>
				<title>
					PMD
					<xsl:value-of select="//pmd:pmd/@version" />
					Report
				</title>

			</head>
			<body>
				<!-- Summary part -->
				<xsl:apply-templates select="." mode="summary" />
				<hr size="1" width="100%" align="left" />
			</body>
		</html>
	</xsl:template>

	<xsl:template match="pmd:pmd" mode="summary">
		<!--** Process root node 'pmd',  for mode 'summary' : number of files, number of violations by severity -->
		<h3>CICD Summary</h3>
		<table class="cicd">
			<tr>
				<th style="width:25%">PMD Version</th>
				<th>1</th>
				<th>2</th>
				<th>3</th>
			</tr>
			<tr>
				<td>
					START_PMD_VERSION<xsl:value-of select="//pmd:pmd/@version" />END_PMD_VERSION
				</td>
				<td>
					START_PRIORITY_1<xsl:value-of select="count(//pmd:violation[@priority = 1])" />END_PRIORITY_1
				</td>
				<td>
					START_PRIORITY_2<xsl:value-of select="count(//pmd:violation[@priority = 2])" />END_PRIORITY_2
				</td>
				<td>
					START_PRIORITY_3<xsl:value-of select="count(//pmd:violation[@priority = 3])" />END_PRIORITY_3
				</td>
			</tr>
		</table>

	</xsl:template>

</xsl:stylesheet>