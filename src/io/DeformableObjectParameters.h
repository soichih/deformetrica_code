/***************************************************************************************
*                                                                                      *
*                                     Deformetrica                                     *
*                                                                                      *
*    Copyright Inria and the University of Utah.  All rights reserved. This file is    *
*    distributed under the terms of the Inria Non-Commercial License Agreement.        *
*                                                                                      *
*                                                                                      *
****************************************************************************************/

#ifndef _DeformableObjectParameters_h
#define _DeformableObjectParameters_h

#include "itkObject.h"
#include "itkObjectFactory.h"

#include <iostream>
#include <string>


class DeformableObjectParameters : public itk::Object
{

public:

	////////////////////////////////////////////////////////////////////////////////////////////////////
	// typedef :
	////////////////////////////////////////////////////////////////////////////////////////////////////

	typedef DeformableObjectParameters Self;
	typedef itk::SmartPointer<Self> Pointer;
	typedef itk::SmartPointer<const Self> ConmlxstPointer;


	////////////////////////////////////////////////////////////////////////////////////////////////////
	// Constructor(s) / Destructor :
	////////////////////////////////////////////////////////////////////////////////////////////////////

	DeformableObjectParameters();

	~DeformableObjectParameters();


	////////////////////////////////////////////////////////////////////////////////////////////////////
	// Encapsulation method(s) :
	////////////////////////////////////////////////////////////////////////////////////////////////////

	// Name of the XML file that has been used to generate this DeformableObjectParameters object
	inline void SetXMLFileName(const char* fn){ m_XMLFileName = fn; }
	inline const char* GetXMLFileName() const { return m_XMLFileName; }
	
	
	// Compulsory parameters
	itkGetMacro(DeformableObjectType, std::string);
	itkSetMacro(DeformableObjectType, std::string);

	itkGetMacro(DataSigma, double);
	itkSetMacro(DataSigma, double);

	itkGetMacro(DataSigma_Normalized_Hyperparameter, double);
	itkSetMacro(DataSigma_Normalized_Hyperparameter, double);

	itkGetMacro(DataSigma_Prior, double);
	itkSetMacro(DataSigma_Prior, double);

	// compulsory only if DeformableObjectType is a current
	itkGetMacro(KernelWidth, double);
	itkSetMacro(KernelWidth, double);

	// Optionnal parameters
	itkGetMacro(ImageGridDownsampling, double);
	itkSetMacro(ImageGridDownsampling, double);

	itkGetMacro(KernelType, std::string);
	itkSetMacro(KernelType, std::string);

	itkGetMacro(Filename, std::string);
	itkSetMacro(Filename, std::string);

	// itkGetMacro(P3MWorkingSpacingRatio, double);
	// itkSetMacro(P3MWorkingSpacingRatio, double);
	// 
	// itkGetMacro(P3MPaddingFactor, double);
	// itkSetMacro(P3MPaddingFactor, double);

	itkGetMacro(AnatomicalCoordinateSystem, std::string);
	itkSetMacro(AnatomicalCoordinateSystem, std::string);

	inline bool ReOrient() { return m_reOrient; }
	inline void SetReOrient() { m_reOrient = true; }
	inline void UnsetReOrient() { m_reOrient = false; }


//	inline void SetUseParametricTemplateImage(){ m_UseParametricTemplateImage = true; }
//	inline void UnsetUseParametricTemplateImage(){ m_UseParametricTemplateImage = false; }
//	inline bool UseParametricTemplateImage() { return m_UseParametricTemplateImage; }
//
//	itkGetMacro(PhotometricKernelType, std::string);
//	itkSetMacro(PhotometricKernelType, std::string);
//
//	itkGetMacro(PhotometricKernelWidth, double);
//	itkSetMacro(PhotometricKernelWidth, double);

	itkGetMacro(PhotometricCPSpacing, double);
	itkSetMacro(PhotometricCPSpacing, double);


	////////////////////////////////////////////////////////////////////////////////////////////////////
	// Other public method(s) :
	////////////////////////////////////////////////////////////////////////////////////////////////////

	void Update();

	itkNewMacro(Self);

	// Make sure all values are OK
	virtual bool CheckValues();

	virtual void PrintSelf(std::ostream& os);


protected:

	////////////////////////////////////////////////////////////////////////////////////////////////////
	// Attribute(s)
	////////////////////////////////////////////////////////////////////////////////////////////////////

	// Name of the XML file that has been used to generate this DeformableObjectParameters object
	const char* m_XMLFileName;

	std::string m_DeformableObjectType;

	double m_DataSigma;

	double m_DataSigma_Normalized_Hyperparameter;
	double m_DataSigma_Prior;

	std::string m_KernelType;
	std::string m_Filename;

	double m_KernelWidth;
	// double m_P3MWorkingSpacingRatio;
	// double m_P3MPaddingFactor;

	double m_ImageGridDownsampling;

	std::string m_AnatomicalCoordinateSystem;

	bool m_reOrient;

//	bool m_UseParametricTemplateImage;
//	double m_PhotometricKernelWidth;
//	std::string m_PhotometricKernelType;
	double m_PhotometricCPSpacing;

}; /* class DeformableObjectParameters */


#endif /* _DeformableObjectParameters_h */
