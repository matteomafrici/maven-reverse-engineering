stk.v.8.0

BEGIN ReportStyle
Name		AccessSummary

BEGIN ClassId
	Class		Access
END ClassId

BEGIN Header
	StyleType		0
	Title		Access Summary Report
	Date		Yes
	Name		Yes
	DescShort		No
	DescLong		No
	YLog10		No
	Y2Log10		No
	VerticalGridLines		No
	HorizontalGridLines		No
	AnnotationType		Spaced
	NumAnnotations		3
	NumAngularAnnotations		5
	AnnotationRotation		1
	BackgroundColor		#ffffff
	ViewableDuration		0.000000
	RealTimeMode		No
	ReadOnlyMode		Yes
	DayLinesStatus		1
	LegendStatus		1

BEGIN PostProcessor
	Destination	0
	Use	0
	Destination	1
	Use	0
	Destination	2
	Use	0
	Destination	3
	Use	0
END PostProcessor
	NumSections		1
END Header

BEGIN Section
	Name		Section 1
	ClassName		Access
	NameInTitle		Yes
	ExpandMethod		0
	PropMask		4
	ShowIntervals		No
	NumIntervals		0
	NumLines		1

BEGIN Line
	Name		Line 1
	NumElements		4

BEGIN Element
	Name		Access Data-Access Number
	IsIndepVar		No
	Title		Access
	NameInTitle		No
	Service		InviewData
	Element		Access Number
	SumAllowedMask		32
	SummaryOnly		No
	DataType		1
	UnitType		6
	LineStyle		0
	LineWidth		0
	LineColor		#000000
	PointStyle		0
	PointSize		0
	PointColor		#000000
	FillPattern		0
	FillColor		#000000
	PropMask		0
	UseScenUnits		Yes
END Element

BEGIN Element
	Name		Access Data-Start Time
	IsIndepVar		No
	Title		Start Time
	NameInTitle		No
	Service		InviewData
	Element		Start Time
	SumAllowedMask		0
	SummaryOnly		No
	DataType		0
	UnitType		2
	LineStyle		0
	LineWidth		0
	LineColor		#000000
	PointStyle		0
	PointSize		0
	PointColor		#000000
	FillPattern		0
	FillColor		#000000
	PropMask		0
	UseScenUnits		Yes
END Element

BEGIN Element
	Name		Access Data-Stop Time
	IsIndepVar		No
	Title		Stop Time
	NameInTitle		No
	Service		InviewData
	Element		Stop Time
	SumAllowedMask		0
	SummaryOnly		No
	DataType		0
	UnitType		2
	LineStyle		0
	LineWidth		0
	LineColor		#000000
	PointStyle		0
	PointSize		0
	PointColor		#000000
	FillPattern		0
	FillColor		#000000
	PropMask		0
	UseScenUnits		Yes
END Element

BEGIN Element
	Name		Access Data-Duration
	IsIndepVar		No
	Title		Duration
	NameInTitle		No
	Service		InviewData
	Element		Duration
	Format		%.3f
	SumAllowedMask		223
	SummaryOnly		Yes
	SumRequestMask		15
	DataType		0
	UnitType		1
	LineStyle		0
	LineWidth		0
	LineColor		#000000
	PointStyle		0
	PointSize		0
	PointColor		#000000
	FillPattern		0
	FillColor		#000000
	PropMask		0
BEGIN Event
	UseEvent		No
	EventValue		0.000000
	Direction		Both
	CreateFile		No
END Event
	UseScenUnits		Yes
END Element
END Line
END Section
END ReportStyle

