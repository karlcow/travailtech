<?xml version="1.0" encoding="iso-8859-1"?>
<!--

Translate colloquy's transcript format into something that scribe.perl can grok.

Thomas Roessler <tlr@w3.org>, 2009-02-12
$Id: colloquy2normalized.xsl,v 1.1 2009-02-12 00:43:52 roessler Exp $

$Log: colloquy2normalized.xsl,v $
Revision 1.1  2009-02-12 00:43:52  roessler
initial check-in


-->

<xsl:transform version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  
  <xsl:output method="text" encoding='utf-8' />
  
  <xsl:template match="log">
    <xsl:apply-templates select="envelope"/>
  </xsl:template>
  
  <xsl:template match="envelope">
    <xsl:apply-templates select="message">
      <xsl:with-param name="nick"><xsl:value-of select="sender/text()"/></xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="message">
    <xsl:param name="nick"/>
    <xsl:choose>
      <xsl:when test="@action='yes'">
	<xsl:text>* </xsl:text><xsl:value-of select="$nick"/><xsl:text> </xsl:text>
      </xsl:when>
      <xsl:otherwise>
	<xsl:text>&lt;</xsl:text><xsl:value-of select="$nick"/><xsl:text>&gt; </xsl:text>
      </xsl:otherwise>
    </xsl:choose>
    <!--     <xsl:apply-templates select="*|text()" mode="msg"/> -->
    <xsl:value-of select="normalize-space(.)"/>
    <xsl:text>
</xsl:text>
  </xsl:template>
  
  <xsl:template match="text()" mode="msg">
    <xsl:value-of select="."/>
  </xsl:template>
  <xsl:template match="span" mode="msg">
    <xsl:value-of select="text()"/>
  </xsl:template>
  
</xsl:transform>
