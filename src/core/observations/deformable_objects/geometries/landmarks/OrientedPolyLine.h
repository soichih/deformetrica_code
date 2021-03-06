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

#include "Landmark.h"

#include "KernelType.h"

#include "itkSimpleFastMutexLock.h"

#include "vtkPolyData.h"
#include "vtkSmartPointer.h"

#include <cstring>
#include <iostream>
#include <sstream>

/**
 *	\brief 		Oriented curves.
 *
 *	\copyright  Inria and the University of Utah
 *	\version    Deformetrica 2.0
 *
 *	\details    The OrientedPolyLine class inherited from Landmark represents a set of polygonal lines.
 *	            This class uses the current representation of curves, which is sensitive to the orientation
 *	            (change in orientation changes the sign of the curve in the space of currents).
 */
template <class ScalarType, unsigned int Dimension>
class OrientedPolyLine : public Landmark<ScalarType, Dimension>
{
 public:

  ////////////////////////////////////////////////////////////////////////////////////////////////////
  // typedef :
  ////////////////////////////////////////////////////////////////////////////////////////////////////

  /// Landmark type.
  typedef Landmark<ScalarType, Dimension> Superclass;

  /// Deformable object type.
  typedef typename Superclass::Superclass AbstractGeometryType;


  ////////////////////////////////////////////////////////////////////////////////////////////////////
  // Constructor(s) / Destructor :
  ////////////////////////////////////////////////////////////////////////////////////////////////////

  /// Constructor.
  OrientedPolyLine();

  /// Copy constructor.
  OrientedPolyLine(const OrientedPolyLine& other);
  /// Constructor which copies the object and update vertex coordinates
  OrientedPolyLine(const OrientedPolyLine& example, const MatrixType& LandmarkPoints);

  /// Returns a Deformed version of the mesh, where the deformation is given by the position of vertices in \e LandmarkPoints
  std::shared_ptr<OrientedPolyLine> DeformedObject(const MatrixType& LandmarkPoints) const {
	  return std::static_pointer_cast<OrientedPolyLine>(doDeformedObject(LandmarkPoints)); }

  /// Clones the object.
  std::shared_ptr<OrientedPolyLine> Clone() const {
	  return std::static_pointer_cast<OrientedPolyLine>(doClone()); }

  /// Destructor.
  virtual ~OrientedPolyLine();

  // STANLEY
  /*
  virtual int GetDimensionOfDiscretizedObject() const
  {
      int d = 0;
      for (unsigned int dim = 0; dim < Dimension; dim ++)
      {
          d += floor( (Superclass::Superclass::m_BoundingBox(dim,1) - Superclass::Superclass::m_BoundingBox(dim,0)) / m_KernelWidth );
      }
      d *= Dimension;
      return d;
  }
  */
  // PIETRO
  virtual unsigned long GetDimensionOfDiscretizedObject() const
  {
	  int d = 1;
	  for (unsigned int dim = 0; dim < Dimension; dim ++)
	  {
		  d *= floor( (Superclass::Superclass::m_BoundingBox(dim,1) - Superclass::Superclass::m_BoundingBox(dim,0)) / m_KernelWidth + 1.0);
	  }
	  d *= Dimension;
	  return d;
  }


  ////////////////////////////////////////////////////////////////////////////////////////////////////
  // Encapsulation method(s) :
  ////////////////////////////////////////////////////////////////////////////////////////////////////

  virtual void SetPolyData(vtkPolyData* polyData);

  /// Returns the centers of the cells.
  inline MatrixType GetCenters() const { return m_Centers; }

  /// Returns the tangents of the cells.
  inline MatrixType GetTangents() const { return m_Tangents; }

  /// Returns the number of cells.
  inline int GetNumberOfCells() const { return m_NumCells; }

  ///	Returns the type of the kernel.
  inline KernelEnumType GetKernelType() const { return m_KernelType; }
  /// Sets the type of the kernel to \e kernelType.
  inline void SetKernelType(KernelEnumType kernelType) { m_KernelType = kernelType; this->SetModified(); }

  ///	Returns the size of the kernel.
  inline ScalarType GetKernelWidth() const { return m_KernelWidth; }
  /// Sets the size of the kernel to \e h.
  inline void SetKernelWidth(ScalarType h) {	m_KernelWidth = h; this->SetModified(); }

  /// Returns the squared RKHS-norm of itself.
  inline ScalarType GetNormSquared() const { return m_NormSquared; }


  ////////////////////////////////////////////////////////////////////////////////////////////////////
  // Other method(s) :
  ////////////////////////////////////////////////////////////////////////////////////////////////////

  void Update();

  /// See AbstractGeometry::ComputeMatch(AbstractGeometry* target) for details.
  virtual ScalarType ComputeMatch(const std::shared_ptr<AbstractGeometryType> target);

  /// See AbstractGeometry::ComputeMatchGradient(AbstractGeometry* target) for details.
  virtual MatrixType ComputeMatchGradient(const std::shared_ptr<AbstractGeometryType> target);



 protected:

  ////////////////////////////////////////////////////////////////////////////////////////////////////
  // Protected method(s) :
  ////////////////////////////////////////////////////////////////////////////////////////////////////

  /// Returns a Deformed version of the mesh, where the deformation is given by the position of vertices in \e LandmarkPoints
  virtual std::shared_ptr<AbstractGeometryType> doDeformedObject(const MatrixType& LandmarkPoints) const {
	  return std::static_pointer_cast<AbstractGeometryType>(std::make_shared<OrientedPolyLine>(*this, LandmarkPoints)); }

  /// Clones the object.
  virtual std::shared_ptr<AbstractGeometryType> doClone() const {
	  return std::static_pointer_cast<AbstractGeometryType>(std::make_shared<OrientedPolyLine>(*this)); }


  /// Updates the bounding box.
  void UpdateBoundingBox();

  /// Updates the centers and the tangents from the points.
  void UpdateCentersTangents();
  /*
   *	\brief		Computes the centers and the normals from the points.
   *
   *	\details	Given a set of polygonal lines , this method computes from the vertices of the curve
   *				the centers and the tangents of each cell.
   *
   *	\param[in]	Pts			The vertices of the curves.
   *	\param[out]	Centers		The centers of the cells (Size : NumCells x Dimension).
   *	\param[out]	Tangents	The tangents of the cells (Size : NumCells x Dimension).
   */
  //void ComputeCentersTangents(const MatrixType& Pts, MatrixType& Centers, MatrixType& Tangents);

  /// Computes the RKHS-norm of itself.
  void UpdateSelfNorm();



  ////////////////////////////////////////////////////////////////////////////////////////////////////
  // Attribute(s)
  ////////////////////////////////////////////////////////////////////////////////////////////////////

  ///	Matrix coordinates of the centers of the cells  (Size : NumCells x Dimension).
  MatrixType m_Centers;

  ///	Matrix coordinates of the tangents of the cells  (Size : NumCells x Dimension).
  MatrixType m_Tangents;

  /// Number of cells (i.e. polygonal lines).
  int m_NumCells;

  ///	Type of the kernel.
  KernelEnumType m_KernelType;

  ///	Size of the kernel.
  ScalarType m_KernelWidth;

  /// Squared RKHS-norm of the oriented curve.
  ScalarType m_NormSquared;

  /// See Landmark::m_VTKMutex for details.
  itk::SimpleFastMutexLock m_VTKMutex;


}; /* class OrientedPolyLine */

