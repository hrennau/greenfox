<?xml version="1.0" encoding="UTF-8"?>
<!-- 
    Stylesheet upgrading a Greenfox schema:
    (a) attribute @foxpath is replaced with @navigateFOX
    (b) //context/field/@value = '{schemaPath}\...' is replaced with '{schemaURI}/...'
  -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:gfox="http://www.greenfox.org/ns/schema"
    exclude-result-prefixes="xs"
    version="2.0">
    
    <xsl:template match="@foxpath">
        <xsl:attribute name="navigateFOX" select="."/>
    </xsl:template>
    
    <xsl:template match="gfox:field/@value[starts-with(., '${schemaPath}')]">
       <xsl:attribute name="{node-name(.)}" 
                    select="replace(replace(., '\{schemaPath\}', '{schemaURI}'), '\\', '/')"/>
    </xsl:template>
    
    <xsl:template match="@*|node()">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>