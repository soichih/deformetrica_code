/***************************************************************************************
*                                                                                      *
*                                     Deformetrica                                     *
*                                                                                      *
*    Copyright Inria and the University of Utah.  All rights reserved. This file is    *
*    distributed under the terms of the Inria Non-Commercial License Agreement.        *
*                                                                                      *
*                                                                                      *
****************************************************************************************/

#pragma once

#include "LinearInterpImage.h"
#include "itkMutualInformationImageToImageMetric.h"


/**
 *  \brief      An image using linear interpolation of voxel values and Mutual information metric.
 *
 *  \copyright  Inria and the University of Utah
 *  \version    Deformetrica 2.0
 *
 *  \details    The class does not implement ComputeMatchGradient and can therefore only be used for simulation-like algorithms.
 */
template<class ScalarType, unsigned int Dimension>
class MutualInformationImage : public LinearInterpImage<ScalarType, Dimension>
{
	public:

	////////////////////////////////////////////////////////////////////////////////////////////////////
	// typedef
	////////////////////////////////////////////////////////////////////////////////////////////////////

	/// Abstract image type.
	typedef LinearInterpImage<ScalarType, Dimension> Superclass;
	/// Abstract Geometry type.
	typedef typename Superclass::Superclass AbstractGeometryType;
	/// ITK image type.
	typedef itk::Image<ScalarType, Dimension> ImageType;
	/// ITK image pointer type.
	typedef typename ImageType::Pointer ImageTypePointer;
  	///ITK Mutual Information Metric Type
	typedef itk::MutualInformationImageToImageMetric<ImageType,ImageType> MutualInformationMetricType;


	////////////////////////////////////////////////////////////////////////////////////////////////////
	// Constructor(s) / Destructor :
	////////////////////////////////////////////////////////////////////////////////////////////////////

	/// Constructor.
	MutualInformationImage();

	/// Destructor.
	virtual ~MutualInformationImage();

	/// Copy constructor.
	MutualInformationImage(const MutualInformationImage& other);
	/// Constructor which copies the object and resample the image
	MutualInformationImage(const MutualInformationImage& example, const MatrixType& ImagePoints);

	/// Returns a Deformed version of the image, where the deformation is given by the position of voxels positions in \e ImagePoints
	std::shared_ptr<MutualInformationImage> DeformedObject(const MatrixType& ImagePoints) const {
		return std::static_pointer_cast<MutualInformationImage>(doDeformedObject(ImagePoints)); }

	/// Clones the object.
	std::shared_ptr<MutualInformationImage> Clone() const { return std::static_pointer_cast<MutualInformationImage>(doClone()); }


	////////////////////////////////////////////////////////////////////////////////////////////////////
	// Other method(s) :
	////////////////////////////////////////////////////////////////////////////////////////////////////

	void Update();

	/// See AbstractGeometry::ComputeMatch(AbstractGeometry* target) for details.
	virtual ScalarType ComputeMatch(const std::shared_ptr<AbstractGeometryType> target);

	/// See AbstractGeometry::ComputeMatchGradient(AbstractGeometry* target) for details.
	virtual MatrixType ComputeMatchGradient(const std::shared_ptr<AbstractGeometryType> target);

	/// Return the dimension of the discretized image, here the number of voxels of the original image
	virtual unsigned long GetDimensionOfDiscretizedObject() const { return Superclass::m_NumberOfVoxels; }


protected:

	////////////////////////////////////////////////////////////////////////////////////////////////////
	// Protected method(s).
	////////////////////////////////////////////////////////////////////////////////////////////////////

	/// Returns a Deformed version of the image, where the deformation is given by the position of voxels positions in \e ImagePoints
	virtual std::shared_ptr<AbstractGeometryType> doDeformedObject(const MatrixType& ImagePoints) const {
		return std::static_pointer_cast<AbstractGeometryType>(std::make_shared<MutualInformationImage>(*this, ImagePoints)); }

	/// Clones the object.
	virtual std::shared_ptr<AbstractGeometryType> doClone() const {
		return std::static_pointer_cast<AbstractGeometryType>(std::make_shared<MutualInformationImage>(*this)); }

};


