#include "DeformetricaConfig.h"

#include "vtkPoints.h"
#include "vtkPointLocator.h"
#include "vtkPolyData.h"
#include "vtkDelaunay3D.h"
#include "vtkSmartPointer.h"
#include "vtkPolyDataReader.h"
#include "vtkPolyDataWriter.h"

#include "vtkParametricEllipsoid.h"

#include "vtkTriangleFilter.h"
#include "vtkWindowedSincPolyDataFilter.h"

#include <src/support/linear_algebra/LinearAlgebra.h>
#include <cmath>

using namespace def::algebra;

int main(int argc, char **argv) {

  if (argc < 4) {
    std::cerr << "Usage: " << argv[0] << " outfilename sourceFileName PointSet1 PointSet2 etc.." << std::endl;
    return -1;
  }

  int numShapes = argc - 3;
  char *outfilename = argv[1];
  char *sourcefilename = argv[2];

  // Read source file (typically the mesh of a sphere).
  vtkSmartPointer<vtkPolyDataReader> SourceReader =
      vtkSmartPointer<vtkPolyDataReader>::New();
  SourceReader->SetFileName(sourcefilename);
  SourceReader->Update();
  vtkSmartPointer<vtkPolyData> source = SourceReader->GetOutput();

  int NbSourcePts = source->GetNumberOfPoints();
  VectorType centerSource(3, 0.0);
  for (int i = 0; i < NbSourcePts; i++) {
    double p[3];
    source->GetPoint(i, p);
    for (unsigned int dim = 0; dim < 3; dim++)
      centerSource(dim) += p[dim];
  }
  centerSource /= NbSourcePts;

  double radius = 0.0;
  for (int i = 0; i < NbSourcePts; i++) {
    double p[3];
    source->GetPoint(i, p);
    double norm2 = 0.0;
    for (unsigned int dim = 0; dim < 3; dim++)
      norm2 += (p[dim] - centerSource(dim)) * (p[dim] - centerSource(dim));

    radius += sqrt(norm2);
  }
  radius /= NbSourcePts;

  // center and normalize the radius of the sphere
  for (int i = 0; i < NbSourcePts; i++) {
    double p[3];
    source->GetPoint(i, p);
    for (unsigned int dim = 0; dim < 3; dim++)
      p[dim] = (p[dim] - centerSource[dim]) / radius;

    source->GetPoints()->SetPoint(i, p);
  }

  /// Read objects files.
  std::vector<vtkSmartPointer<vtkPolyData> > shapes(numShapes);
  int TotalNumPts = 0;

  VectorType center(3, 0.0);
  for (int i = 0; i < numShapes; i++) {
    vtkSmartPointer<vtkPolyDataReader> reader =
        vtkSmartPointer<vtkPolyDataReader>::New();
    reader->SetFileName(argv[i + 3]);
    reader->Update();
    vtkSmartPointer<vtkPolyData> sh = reader->GetOutput();
    shapes[i] = sh;

    int numPts = sh->GetNumberOfPoints();
    TotalNumPts += numPts;
    for (int k = 0; k < numPts; k++) {
      double p[3];
      sh->GetPoint(k, p);
      for (int dim = 0; dim < 3; dim++)
        center(dim) += p[dim];
    }
  }
  center /= TotalNumPts;

  MatrixType covM(3, 3, 0.0);
  for (int i = 0; i < numShapes; i++)
    for (int k = 0; k < shapes[i]->GetNumberOfPoints(); k++) {
      double p[3];
      shapes[i]->GetPoint(k, p);
      for (int r = 0; r < 3; r++)
        for (int c = 0; c < 3; c++)
          covM(r, c) += (p[r] - center[r]) * (p[c] - center[c]);
    }

  covM /= (TotalNumPts - 1);

  VectorType D;
  MatrixType R;
  eigvec_sym(D, R, covM);

  for (int i = 0; i < NbSourcePts; i++) {
    double p[3];
    source->GetPoint(i, p);
    // deform source to ellipsoid with main axis aligned with x,y and z direction
    for (unsigned int dim = 0; dim < 3; dim++)
      p[dim] *= 1.5 * sqrt(D(dim));

    // rotate the ellipsoid so that the main axis are parallel to the eigenvectors for R
    MatrixType y(3, 1, 0.0);
    for (unsigned int dim = 0; dim < 3; dim++)
      y(dim, 0) = p[dim];

    y = R * y;
    // translate the ellipsoid to the center of mass of the data
    for (unsigned int dim = 0; dim < 3; dim++)
      p[dim] = y(dim, 0) + center[dim];

    source->GetPoints()->SetPoint(i, p);
  }

  std::cout << "Ellipsoid centered at " << center << std::endl;

  vtkSmartPointer<vtkPolyDataWriter> writer =
      vtkSmartPointer<vtkPolyDataWriter>::New();
  writer->SetFileName(outfilename);
#if (VTK_MAJOR_VERSION <= 5)
  writer->SetInput(source);
#else
  writer->SetInputData(source);
#endif
  writer->Update();

}


