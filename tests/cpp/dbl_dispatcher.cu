//Andrei Schaffer, 07/23/2018: experiments with containers of device functions (functors, lambdas)
//                             requires C++14 for template variables;
//
//nvcc -c -w -std=c++14 --expt-extended-lambda dbl_dispatcher.cu
//nvcc -w -std=c++14 --expt-extended-lambda dbl_dispatcher.cu -o dbl_dispatcher.exe

#include <thrust/device_vector.h>
#include <thrust/tuple.h>
#include <thrust/execution_policy.h>
#include <thrust/system/cuda/execution_policy.h>
#include <thrust/copy.h>
#include <thrust/sort.h>
#include <thrust/binary_search.h>
#include <thrust/unique.h>
#include <thrust/transform.h>
#include <thrust/sequence.h>
#include <thrust/iterator/counting_iterator.h>
#include <thrust/iterator/constant_iterator.h>
#include <thrust/reduce.h>
#include <thrust/distance.h>
#include <thrust/count.h>
#include <thrust/extrema.h>

#include <iostream>
#include <vector>
#include <tuple>
#include <cassert>
#include <iterator>

#include "visitor_set.hpp"

int main(void)
{
  std::vector<short> v_types{Types::DOUBLE, Types::INT, Types::DOUBLE};
  std::vector<short> v_ops{OpTypes::SUM, OpTypes::MAX, OpTypes::MIN};
  
  size_t ncols = v_ops.size();
  
  AggregationManager man(v_types, v_ops);
  Vector<GnctrTypeErased>& d_fte = man.get_vfctrs();

  using IndexT = int;
  size_t nrows = 6;
  
  std::vector<IndexT> h_keys{0,0,1,1,2,2};
  std::vector<double> hc1{1.13, 2.87, -1.01, 5.01, 2.17, 1.83};//SUM
  std::vector<int>    hc2{-1, 1, -3, 2, 0, 3};                 //MAX
  std::vector<double> hc3{1.13, 0.87, -1.01, 5.01, 2.17, 0.83};//MIN

  //type ids:
  //
  Vector<short> d_types = v_types;

  //keys in:
  //
  Vector<IndexT> d_keys = h_keys;

  //agg in:
  //
  Vector<double> dc1 = hc1;
  Vector<int>    dc2 = hc2;
  Vector<double> dc3 = hc3;
  Vector<void*>  d_cols(ncols, nullptr);
  d_cols[0] = dc1.data().get();
  d_cols[1] = dc2.data().get();
  d_cols[2] = dc3.data().get();

  //agg out:
  //
  Vector<double> dagg1(nrows,0);
  Vector<int>    dagg2(nrows, 0);
  Vector<double> dagg3(nrows, 0);
  Vector<void*>  dvout(ncols, nullptr);
  dvout[0] = dagg1.data().get();
  dvout[1] = dagg2.data().get();
  dvout[2] = dagg3.data().get();

  //keys out:
  //
  Vector<IndexT> dk1(nrows, 0);
  Vector<IndexT> dk2(nrows, 0);
  Vector<IndexT> dk3(nrows, 0);
  Vector<IndexT*> dkout(ncols, nullptr);
  dkout[0] = dk1.data().get();
  dkout[1] = dk2.data().get();
  dkout[2] = dk3.data().get();

  //make the reduction visitor machinery on device
  //
  ReductionFactory<IndexT> rf(nrows, d_fte, d_keys, d_cols, dkout, dvout, d_types);
                      
  //captures:
  //
  BaseVisitor** p_ptr_visitors       = rf.get_visitors().data().get();
  BaseVector**  p_ptr_typed_columns  = rf.get_columns().data().get();

  //Apply Visitors to TypedVectors:
  //
  thrust::for_each(thrust::make_counting_iterator<IndexT>(0), thrust::make_counting_iterator<IndexT>((IndexT)ncols),
                   [p_ptr_typed_columns, p_ptr_visitors] __host__ __device__ (IndexT col_indx){
                     p_ptr_typed_columns[col_indx]->Apply(p_ptr_visitors[col_indx]);
                   });

  std::cout<<"results: ";
  print_v(dagg1, std::cout);
  print_v(dagg2, std::cout);
  print_v(dagg3, std::cout);
                    
  std::cout << "Done!" << std::endl;
  return 0;
}