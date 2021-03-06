/***************************************************************************************
*                                                                                      *
*                                     Deformetrica                                     *
*                                                                                      *
*    Copyright Inria and the University of Utah.  All rights reserved. This file is    *
*    distributed under the terms of the Inria Non-Commercial License Agreement.        *
*                                                                                      *
*                                                                                      *
****************************************************************************************/

#ifndef _DeformationFieldIO_h
#define _DeformationFieldIO_h

#include "LinearAlgebra.h"
#include <vector>

#include "Diffeos.h"
#include "AnatomicalCoordinateSystem.h"
#include "Landmark.h"
#include "src/core/observations/deformable_objects/DeformableMultiObject.h"

#include "itkImage.h"
#include "itkRawImageIO.h"
#include "itkImageFileWriter.h"
#include "itkImageFileReader.h"
#include "metaImage.h"
#include "itkImageAlgorithm.h"
#include "itkOrientImageFilter.h"

#include "itkImageIOBase.h"

#include <cstring>
#include <iostream>
#include <string>
#include <sstream>
#include <algorithm>

using namespace def::algebra;
/**
 *  \brief      A metadata writer of Deformation Fields.
 *
 *  \author     Ana Beatriz G. Fouquier (ICM, France)
 *  \date       2014-04-10
 *  \version    1.0
 *
 *  \details    The DeformationFieldIO enables to save in a metada file (.mha) the resulting displacement field obtained from
 *              a diffeomorphism that morphs a deformable object onto another.
 *              If the deformable object has an associated anatomical coordinate system (as in the case of medical images
 *              and meshes representing anatomical objects), the user may define this system in order to save the deformation field
 *              in the correct orientation.
 */
template<class ScalarType, unsigned int Dimension>
class DeformationFieldIO {
 public:

  ////////////////////////////////////////////////////////////////////////////////////////////////////
  // typedef :
  ////////////////////////////////////////////////////////////////////////////////////////////////////

  /// 2D Vector type
  typedef typename itk::Vector<double, 2> Vector2DType;

  /// 2D Image type.
  typedef itk::Image<Vector2DType, 2> DisplacementField2DType;
  typedef typename DisplacementField2DType::Pointer DisplacementField2DTypePointer;
  typedef typename itk::Point<ScalarType, 2> Point2DType;

  /// 3D Vector type
  typedef typename itk::Vector<double, 3> Vector3DType;

  /// 3D Image type.
  typedef itk::Image<Vector3DType, 3> DisplacementField3DType;
  typedef typename DisplacementField3DType::Pointer DisplacementField3DTypePointer;
  typedef typename itk::Point<ScalarType, 3> Point3DType;

  typedef ScalarType ElemType;

  /// Deformation type.
  typedef Diffeos<ScalarType, Dimension> DiffeosType;

  /// Deformable object type.
  typedef AbstractGeometry<ScalarType, Dimension> AbstractGeometryType;
  /// List of deformable objects type.
  typedef std::vector<std::shared_ptr<AbstractGeometryType>> DeformableObjectList;
  typedef typename DeformableObjectList::iterator DeformableObjectListIterator;

  /// Deformable multi-object type.
  typedef DeformableMultiObject<ScalarType, Dimension> DeformableMultiObjectType;



  ////////////////////////////////////////////////////////////////////////////////////////////////////
  // Constructor(s) / Destructor :
  ////////////////////////////////////////////////////////////////////////////////////////////////////

  DeformationFieldIO();

  ~DeformationFieldIO();



  ////////////////////////////////////////////////////////////////////////////////////////////////////
  // Encapsulation method(s) :
  ////////////////////////////////////////////////////////////////////////////////////////////////////

  /// Sets the deformation to \e def.
  inline void SetDiffeos(std::shared_ptr<DiffeosType> def) { m_Def = def; }

  /// Sets the factor for spacing points in the data domain = kernel_width / factor.
  /// Default factor is 5.
  inline void SetFactor(ScalarType val) { if (val > 1.0) m_Factor = val; }

  inline void SetAnatomicalCoordinateSystemLabel(std::string label) {
    if (!m_CoordSystem.SetAnatomicalCoordinateSystemLabel(label)) {
      std::cout << "Invalid anatomical orientation code for deformation field image: setting it to default LPS / Nifti."
                << std::endl;
      m_CoordSystem.SetAnatomicalCoordinateSystemLabel("LPS");
    }
  }


  ////////////////////////////////////////////////////////////////////////////////////////////////////
  // Other method(s) :
  ////////////////////////////////////////////////////////////////////////////////////////////////////

  // Write metaimages corresponding to the deformation fields obtained from the flow of control points and momenta
  // for a deformable object.
  // If the flag "finalField" is set to true, a single deformation field metaimage will be created,
  // corresponding to the displacement between the final and initial points.
  void WriteDeformationField(const std::string &name, bool finalField = false);

  // Update: calls WriteDeformationField with finalField=true and name="output"
  void Update();

 protected:

  ////////////////////////////////////////////////////////////////////////////////////////////////////
  // Method(s) :
  ////////////////////////////////////////////////////////////////////////////////////////////////////
  bool WriteDeformationField3DImage(const std::string &fn, bool finalField);

  //void ImageToDeformationField();



  ////////////////////////////////////////////////////////////////////////////////////////////////////
  // Attribute(s)
  ////////////////////////////////////////////////////////////////////////////////////////////////////

  /// Spacing factor of the regular lattice that embeds the control points (>= 1). Default is 5mm.
  ScalarType m_Factor;

  /// Entity representing the deformation.
  std::shared_ptr<DiffeosType> m_Def;

  /// String containing the name of the file which be will saved thanks to the Update() method.
  const char *m_FileName;

  AnatomicalCoordinateSystem<ScalarType, Dimension> m_CoordSystem;

};

#endif /* _DeformationFieldIO_h */
