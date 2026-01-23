<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

	<xsl:template match="/DbObjects">
		<xsl:element name="Objects">
			<xsl:text>&#xa;</xsl:text>
			<xsl:element name="Keys">
				<xsl:text>&#xa;</xsl:text>
				<xsl:apply-templates select="//DbObject" />
			</xsl:element>
			<xsl:text>&#xa;</xsl:text>
			
			<xsl:apply-templates select="//Columns" />
			<xsl:text>&#xa;</xsl:text>
		</xsl:element>
	</xsl:template>

	<xsl:template name="BuildKeys" match="//DbObject">
		<xsl:variable name="tablename">
			<xsl:value-of select="Key/Table/@Name" /> 
		</xsl:variable>
		<xsl:element name="{$tablename}">
			<xsl:for-each select="Key/Table/Prop">
				<xsl:value-of select="@Name" />
				<xsl:if test="following-sibling::*">
					<xsl:text>,</xsl:text>
				</xsl:if>
			</xsl:for-each>
		</xsl:element>
		<xsl:text>&#xa;</xsl:text>
	</xsl:template>

	<xsl:template name="BuildObjects" match="//Columns">
		<xsl:variable name="tablename">
			<xsl:value-of select="ancestor::DbObject//Table/@Name" />
		</xsl:variable>
		<xsl:element name="{$tablename}">
			<xsl:text>&#xa;</xsl:text>
			<xsl:for-each select="Column">
				<xsl:variable name="columnname">
					<xsl:value-of select="@Name" />
				</xsl:variable>
				
				<!-- quick test to exclude columns XObjectKey,XDateInserted,... -->
				<xsl:if test="not(starts-with($columnname,'X'))">
					<xsl:element name="{$columnname}">
						
						<xsl:choose>
							<!-- foreign key -->
							<xsl:when test="Key/Table">
								<xsl:variable name="fktablename">
									<xsl:value-of select="Key/Table/@Name" />
								</xsl:variable>
								<xsl:element name="{$fktablename}">
										<xsl:attribute name="where"><xsl:value-of select="Key/Table/Prop/@Name" /><xsl:text> = '</xsl:text><xsl:value-of select="Key/Table/Prop/Value" /><xsl:text>'</xsl:text></xsl:attribute>
								</xsl:element>
							</xsl:when>
							<!-- simple value -->
							<xsl:otherwise>
								<xsl:value-of select="Value" />
							</xsl:otherwise>
						</xsl:choose>
						
					</xsl:element>
					<xsl:text>&#xa;</xsl:text>
				</xsl:if>
				
			</xsl:for-each>
		</xsl:element>
		<xsl:text>&#xa;</xsl:text>
		<xsl:text>&#xa;</xsl:text>
	</xsl:template>

</xsl:stylesheet>