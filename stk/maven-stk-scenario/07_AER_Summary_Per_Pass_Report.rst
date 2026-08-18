stk.v.9.0
WrittenBy    STK_v9.3.0

BEGIN ReportStyle
Name		AERSummary

BEGIN ClassId
	Class		Access
END ClassId

BEGIN Header
	StyleType		0
	Title		Inview Azimuth, Elevation, & Range
	Date		Yes
	Name		Yes
	DescShort		No
	DescLong		No
	YLog10		No
	Y2Log10		No
	YUseWholeNumbers		No
	Y2UseWholeNumbers		No
	VerticalGridLines		No
	HorizontalGridLines		No
	AnnotationType		Spaced
	NumAnnotations		3
	NumAngularAnnotations		5
	ShowYAnnotations		Yes
	AnnotationRotation		1
	BackgroundColor		#ffffff
	ForegroundColor		#000000
	ViewableDuration		3600.000000
	RealTimeMode		No
	ReadOnlyMode		Yes
	DayLinesStatus		1
	LegendStatus		1
	LegendLocation		1

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
	Title		AER reported in object's default AER frame
	NameInTitle		Yes
	ExpandMethod		0
	PropMask		2
	Granularity		60.000000
	ShowIntervals		No
	NumIntervals		0
	NumLines		1

BEGIN Line
	Name		Line 1
	NumElements		4

BEGIN Element
	Name		Time
	IsIndepVar		Yes
	IndepVarName		Time
	Title		Time
	NameInTitle		No
	Service		InviewAER
	Type		Default
	Element		Time
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
	Name		AER Data-Default-Azimuth
	IsIndepVar		No
	IndepVarName		Time
	Title		Azimuth
	NameInTitle		No
	Service		InviewAER
	Type		Default
	Element		Azimuth
	Format		%.3f
	SumAllowedMask		1543
	SummaryOnly		Yes
	DataType		0
	UnitType		20
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
	UseScenUnits		No
BEGIN Units
		LongitudeUnit		Degrees
END Units
END Element

BEGIN Element
	Name		AER Data-Default-Elevation
	IsIndepVar		No
	IndepVarName		Time
	Title		Elevation
	NameInTitle		No
	Service		InviewAER
	Type		Default
	Element		Elevation
	Format		%.3f
	SumAllowedMask		1543
	SummaryOnly		Yes
	SumRequestMask		7
	DataType		0
	UnitType		3
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
	UseScenUnits		No
BEGIN Units
		AngleUnit		Degrees
END Units
END Element

BEGIN Element
	Name		AER Data-Default-Range
	IsIndepVar		No
	IndepVarName		Time
	Title		Range
	NameInTitle		No
	Service		InviewAER
	Type		Default
	Element		Range
	Format		%.6f
	SumAllowedMask		1543
	SummaryOnly		Yes
	SumRequestMask		7
	DataType		0
	UnitType		0
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

BEGIN LineAnnotations
END LineAnnotations
END ReportStyle

