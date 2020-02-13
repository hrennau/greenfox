# greenfox
A command-line tool for validating filesystem trees against a greenfox schema.

A **greenfox schema** is a set of conditions constraining a **file system tree**. 
The file system tree can be **validated** against the schema, using greenfox.xq, the greenfox processor. 
The result of validation is a **validation report**. A validation report indicates **conformance** - 
whether the file system tree conforms to the schema - and it supplies **validation results**. 
Each validation result describes the outcome of validating a single resource against a single 
constraint. 

Currently, the following result report formats are supported:

- redTree - only errors, grouped by resource
- whiteTree - all results, grouped by resource
- red - only errors, not grouped 
- white - all results, not grouped

For an introduction see in the **documentation folder**:

- greenfox-xmlprague-2020.pdf
- greenfox-xmlprague-2020.pptx
- greenfox-manual.docx

For schema examples, see folder example-schemas.

As of this writing (2020-02-14), the manual is still rudimentary and most folders
under example-schemas are still empty.



