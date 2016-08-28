local TransformationMatrix3x4Quat, parent = torch.class('nn.TransformationMatrix3x4Quat', 'nn.Module')

--[[
TransformMatrixGenerator(useRotation, useScale, useTranslation) :
TransformMatrixGenerator:updateOutput(transformParams)
TransformMatrixGenerator:updateGradInput(transformParams, gradParams)

This module can be used in between the localisation network (that outputs the
parameters of the transformation) and the AffineGridGeneratorBHWD (that expects
an affine transform matrix as input).

The goal is to be able to use only specific transformations or a combination of them.

If no specific transformation is specified, it uses a fully parametrized
linear transformation and thus expects 6 parameters as input. In this case
the module is equivalent to nn.View(2,3):setNumInputDims(2).

Any combination of the 3 transformations (rotation, scale and/or translation)
can be used. The transform parameters must be supplied in the following order:
rotation (1 param), scale (1 param) then translation (2 params).

Example:
AffineTransformMatrixGenerator(true,false,true) expects as input a tensor of
if size (B, 3) containing (rotationAngle, translationX, translationY).
]]

function TransformationMatrix3x4Quat:__init(useRotation, useScale, useTranslation)
  parent.__init(self)

  -- if no specific transformation, use fully parametrized version
  self.fullMode = not(useRotation or useScale or useTranslation)

  if not self.fullMode then
    self.useRotation = useRotation
    self.useScale = useScale
    self.useTranslation = useTranslation
  end
end

function TransformationMatrix3x4Quat:check(input)
  if self.fullMode then
    assert(input:size(2)==8, 'Expected 7 parameters, got ' .. input:size(2))
  else
    local numberParameters = 0
    if self.useRotation then
      numberParameters = numberParameters + 4
    end
    if self.useScale then
      numberParameters = numberParameters + 1
    end
    if self.useTranslation then
      numberParameters = numberParameters + 3
    end
    assert(input:size(2)==numberParameters, 'Expected '..numberParameters..
                                            ' parameters, got ' .. input:size(2))
  end
end

local function addOuterDim(t)
   local sizes = t:size()
   local newsizes = torch.LongStorage(sizes:size()+1)
   newsizes[1]=1
   for i=1,sizes:size() do
      newsizes[i+1]=sizes[i]
   end
   return t:view(newsizes)
end


local function dR_by_dqi(transparams, RotMats, which_qi)

      local q0 = transparams:select(2,1)
      local q1 = transparams:select(2,2)
      local q2 = transparams:select(2,3)
      local q3 = transparams:select(2,4)

      local q0_sqr = torch.pow(q0,2)
      local q1_sqr = torch.pow(q1,2)
      local q2_sqr = torch.pow(q2,2)
      local q3_sqr = torch.pow(q3,2)
      	
      local q_sum  = q0_sqr + q1_sqr + q2_sqr + q3_sqr
      local q_mag  = torch.pow(q_sum,0.5)	

      --print ('--- qsum is --\n')
      --print ( q_sum )
      
      local qsum_inv_tensor = torch.Tensor(RotMats:size()):zero()	  
        	   
      local q0_div_qsum_tensor   = torch.Tensor(RotMats:size()):zero()
      local q1_div_qsum_tensor   = torch.Tensor(RotMats:size()):zero()
      local q2_div_qsum_tensor   = torch.Tensor(RotMats:size()):zero()
      local q3_div_qsum_tensor   = torch.Tensor(RotMats:size()):zero()

      local q_sum_inv = torch.pow(q_sum,-1)-- - torch.cmul(torch.pow(q_mag,-3),q0_sqr)
     
       --local dq1 = torch.pow(q_sum,-1)-- - torch.cmul(torch.pow(q_mag,-3),q1_sqr)
      --local dq2 = torch.pow(q_sum,-1)-- - torch.cmul(torch.pow(q_mag,-3),q2_sqr)
      --local dq3 = torch.pow(q_sum,-1)-- - torch.cmul(torch.pow(q_mag,-3),q3_sqr)

      --- may need q0q1 (q_mag)^{-3/2} 	


      --- I think the derivative with respect to raw parameters will be 
      --- dR/dq_j = sum_{i=1}^{N} dR/dq_i' * dq_i'/dq_j -- I'm not sure about this one...
      --- or is it this: dR/dq_j = 1/q.q * dR/dq_j + R * (-2 q_i ) / (q.q) (q.q)	
	
      for b = 1, transparams:size(1) do 	
      
		--qsum_inv_tensor[b]:fill(q_sum_inv[b])
      		
		--q0_div_qsum_tensor[b]:fill(-2*q0[b]*q_sum_inv[b])
      		--q1_div_qsum_tensor[b]:fill(-2*q1[b]*q_sum_inv[b])
      		--q2_div_qsum_tensor[b]:fill(-2*q2[b]*q_sum_inv[b])
      		--q3_div_qsum_tensor[b]:fill(-2*q3[b]*q_sum_inv[b])
		
		qsum_inv_tensor[b]:fill(1)
		
		q0_div_qsum_tensor[b]:fill(0)
      		q1_div_qsum_tensor[b]:fill(0)
      		q2_div_qsum_tensor[b]:fill(0)
      		q3_div_qsum_tensor[b]:fill(0)
      end

      --print (q0_mul_tensor)		
      --print (q1_mul_tensor)		
      --print (q2_mul_tensor)		
      --print (q3_mul_tensor)		

      --q0 = torch.cdiv(q0,q_mag)
      --q1 = torch.cdiv(q1,q_mag)
      --q2 = torch.cdiv(q2,q_mag)
      --q3 = torch.cdiv(q3,q_mag)

      print ( transparams ) 	

      if which_qi == 1 then 

	local dR_by_dq0 = torch.Tensor(RotMats:size()):zero()

	dR_by_dq0:select(2,1):select(2,1):copy(q0)	
	dR_by_dq0:select(2,1):select(2,2):copy(-q3)
	dR_by_dq0:select(2,1):select(2,3):copy(q2)		

	dR_by_dq0:select(2,2):select(2,1):copy(q3)	
	dR_by_dq0:select(2,2):select(2,2):copy(q0)	
	dR_by_dq0:select(2,2):select(2,3):copy(-q1)	

	dR_by_dq0:select(2,3):select(2,1):copy(-q2)	
	dR_by_dq0:select(2,3):select(2,2):copy(q1)	
	dR_by_dq0:select(2,3):select(2,3):copy(q0)	

	print ( dR_by_dq0 )
	dR_by_dq0:mul(2)


	return torch.bmm(dR_by_dq0,qsum_inv_tensor) --+ torch.bmm(RotMats,q0_div_qsum_tensor)

      elseif which_qi ==2 then	

	local dR_by_dq1 = torch.Tensor(RotMats:size()):zero()
	
	dR_by_dq1:select(2,1):select(2,1):copy(q1)	
	dR_by_dq1:select(2,1):select(2,2):copy(q2)	
	dR_by_dq1:select(2,1):select(2,3):copy(q3)	
	
	dR_by_dq1:select(2,2):select(2,1):copy(q2)	
	dR_by_dq1:select(2,2):select(2,2):copy(-q1)	
	dR_by_dq1:select(2,2):select(2,3):copy(-q0)	
	
	dR_by_dq1:select(2,3):select(2,1):copy(q3)	
	dR_by_dq1:select(2,3):select(2,2):copy(q0)	
	dR_by_dq1:select(2,3):select(2,3):copy(-q1)	
	
	print ( dR_by_dq1 )
	dR_by_dq1:mul(2)
	
	
	return torch.bmm(dR_by_dq1,qsum_inv_tensor) --+ torch.bmm(RotMats,q1_div_qsum_tensor)

      elseif which_qi == 3 then
		
	local dR_by_dq2 = torch.Tensor(RotMats:size()):zero()
	
	dR_by_dq2:select(2,1):select(2,1):copy(-q2)	
	dR_by_dq2:select(2,1):select(2,2):copy(q1)	
	dR_by_dq2:select(2,1):select(2,3):copy(q0)	
	
	dR_by_dq2:select(2,2):select(2,1):copy(q1)	
	dR_by_dq2:select(2,2):select(2,2):copy(q2)	
	dR_by_dq2:select(2,2):select(2,3):copy(q3)	
	
	dR_by_dq2:select(2,3):select(2,1):copy(-q0)	
	dR_by_dq2:select(2,3):select(2,2):copy(q3)	
	dR_by_dq2:select(2,3):select(2,3):copy(-q2)	
	
	print ( dR_by_dq2 )
	dR_by_dq2:mul(2)

	return torch.bmm(dR_by_dq2,qsum_inv_tensor) --+ torch.bmm(RotMats,q2_div_qsum_tensor)

      elseif which_qi == 4 then

	local dR_by_dq3 = torch.Tensor(RotMats:size()):zero()
	
	dR_by_dq3:select(2,1):select(2,1):copy(-q3)	
	dR_by_dq3:select(2,1):select(2,2):copy(-q0)	
	dR_by_dq3:select(2,1):select(2,3):copy(q1)	
	
	dR_by_dq3:select(2,2):select(2,1):copy(q0)	
	dR_by_dq3:select(2,2):select(2,2):copy(-q3)	
	dR_by_dq3:select(2,2):select(2,3):copy(q2)	
	
	dR_by_dq3:select(2,3):select(2,1):copy(q1)	
	dR_by_dq3:select(2,3):select(2,2):copy(q2)	
	dR_by_dq3:select(2,3):select(2,3):copy(q3)	
	
	print ( dR_by_dq3 )
	dR_by_dq3:mul(2)

	return torch.bmm(dR_by_dq3,qsum_inv_tensor) --+ torch.bmm(RotMats,q3_div_qsum_tensor)

      end	 
end


function TransformationMatrix3x4Quat:updateOutput(_tranformParams)
  local transformParams
  if _tranformParams:nDimension()==1 then
    transformParams = addOuterDim(_tranformParams)
  else
    transformParams = _tranformParams
  end

  self:check(transformParams)
  local batchSize = transformParams:size(1)

  if self.fullMode then
    self.output = transformParams:view(batchSize, 3, 4)
  else
    local completeTransformation = torch.zeros(batchSize,4,4):typeAs(transformParams)
    completeTransformation:select(3,1):select(2,1):add(1)
    completeTransformation:select(3,2):select(2,2):add(1)
    completeTransformation:select(3,3):select(2,3):add(1)
    completeTransformation:select(3,4):select(2,4):add(1)
    local transformationBuffer = torch.Tensor(batchSize,4,4):typeAs(transformParams)

    local paramIndex = 1
    if self.useRotation then

      local q0 = transformParams:select(2,paramIndex)	
      local q1 = transformParams:select(2,paramIndex+1)	
      local q2 = transformParams:select(2,paramIndex+2)
      local q3 = transformParams:select(2,paramIndex+3)

     print ('**** In updateOutput, before **** \n')
     print ( transformParams )	

      paramIndex = paramIndex + 4

      local q0_sqr = torch.pow(q0,2)	
      local q1_sqr = torch.pow(q1,2)	
      local q2_sqr = torch.pow(q2,2)	
      local q3_sqr = torch.pow(q3,2)	
      
      local q_sum  = q0_sqr + q1_sqr + q2_sqr + q3_sqr
      local q_mag  = torch.pow(q_sum,0.5)

      --q0 = torch.cdiv(q0,q_mag) 	
      --q1 = torch.cdiv(q1,q_mag) 	
      --q2 = torch.cdiv(q2,q_mag) 	
      --q3 = torch.cdiv(q3,q_mag) 	


      local updated_qs = torch.Tensor(transformParams:size())

      updated_qs:select(2,1):copy(q0)	
      updated_qs:select(2,2):copy(q1)
      updated_qs:select(2,3):copy(q2)
      updated_qs:select(2,4):copy(q3)
      
      print ('**** In updateOutput, after **** \n')
      print ( updated_qs )	 	
      
      local q0_sqr = torch.pow(q0,2)	
      local q1_sqr = torch.pow(q1,2)	
      local q2_sqr = torch.pow(q2,2)	
      local q3_sqr = torch.pow(q3,2)	

      completeTransformation:select(2,1):select(2,1):copy(q0_sqr+q1_sqr-q2_sqr-q3_sqr)	
      completeTransformation:select(2,1):select(2,2):copy(torch.cmul(q1,q2):mul(2) - torch.cmul(q0,q3):mul(2))	
      completeTransformation:select(2,1):select(2,3):copy(torch.cmul(q1,q3):mul(2) + torch.cmul(q0,q2):mul(2))	

      print (completeTransformation)

      completeTransformation:select(2,2):select(2,1):copy(torch.cmul(q1,q2):mul(2) + torch.cmul(q0,q3):mul(2))	
      completeTransformation:select(2,2):select(2,2):copy(q0_sqr - q1_sqr + q2_sqr - q3_sqr)	
      completeTransformation:select(2,2):select(2,3):copy(torch.cmul(q2,q3):mul(2) - torch.cmul(q0,q1):mul(2))	
      
      print (completeTransformation)

      completeTransformation:select(2,3):select(2,1):copy(torch.cmul(q1,q3):mul(2) - torch.cmul(q0,q2):mul(2))	
      completeTransformation:select(2,3):select(2,2):copy(torch.cmul(q2,q3):mul(2) + torch.cmul(q0,q1):mul(2))	
      completeTransformation:select(2,3):select(2,3):copy(q0_sqr - q1_sqr - q2_sqr + q3_sqr)	

      print (completeTransformation)	

    end
    self.rotationOutput = completeTransformation:narrow(2,1,3):narrow(3,1,3):clone()

    if self.useScale then
    --  local scaleFactors = transformParams:select(2,paramIndex)
      paramIndex = paramIndex + 1

      transformationBuffer:zero()
      transformationBuffer:select(3,1):select(2,1):copy(scaleFactors)
      transformationBuffer:select(3,2):select(2,2):copy(scaleFactors)
      transformationBuffer:select(3,3):select(2,3):add(1)

      completeTransformation = torch.bmm(completeTransformation, transformationBuffer)
    end

    self.scaleOutput = completeTransformation:narrow(2,1,3):narrow(3,1,3):clone()

--    print ( self.scaleOutput ) 

    if self.useTranslation then
      local txs = transformParams:select(2,paramIndex)
      local tys = transformParams:select(2,paramIndex+1)
      local tzs = transformParams:select(2,paramIndex+2)

      transformationBuffer:zero()
      transformationBuffer:select(3,1):select(2,1):add(1)
      transformationBuffer:select(3,2):select(2,2):add(1)
      transformationBuffer:select(3,3):select(2,3):add(1)
      transformationBuffer:select(3,4):select(2,4):add(1)
      
      transformationBuffer:select(3,4):select(2,1):copy(txs)
      transformationBuffer:select(3,4):select(2,2):copy(tys)
      transformationBuffer:select(3,4):select(2,3):copy(tzs)

--      print (transformationBuffer)

      completeTransformation = torch.bmm(completeTransformation, transformationBuffer)

--      print (completeTransformation)
    end

    self.output=completeTransformation:narrow(2,1,3)
  end

  if _tranformParams:nDimension()==1 then
    self.output = self.output:select(1,1)
  end
  return self.output
end


function TransformationMatrix3x4Quat:updateGradInput(_tranformParams, _gradParams)

  local transformParams, gradParams

  if _tranformParams:nDimension()==1 then
    transformParams = addOuterDim(_tranformParams)
    gradParams = addOuterDim(_gradParams):clone()
  else
    transformParams = _tranformParams
    gradParams = _gradParams:clone()
  end

  local batchSize = transformParams:size(1)

  if self.fullMode then

    self.gradInput = gradParams:view(batchSize, 6)

  else

    local paramIndex = transformParams:size(2)
    self.gradInput:resizeAs(transformParams)

    if self.useTranslation then

      local gradInputTranslationParams = self.gradInput:narrow(2,paramIndex-2,3)
      local tParams = torch.Tensor(batchSize, 1, 3):typeAs(transformParams)

      tParams:select(3,1):copy(transformParams:select(2,paramIndex-2))
      tParams:select(3,2):copy(transformParams:select(2,paramIndex-1))
      tParams:select(3,3):copy(transformParams:select(2,paramIndex))
      paramIndex = paramIndex-3

      local selectedOutput     = self.scaleOutput
      local selectedGradParams = gradParams:narrow(3,1,4):narrow(3,4,1):transpose(2,3)
      gradInputTranslationParams:copy(torch.bmm(selectedGradParams, selectedOutput))

      local gradientCorrection = torch.bmm(selectedGradParams:transpose(2,3), tParams)
      gradParams:narrow(3,1,3):narrow(3,1,3):add(1,gradientCorrection)

    end

    if self.useScale then

      local gradInputScaleparams = self.gradInput:narrow(2,paramIndex,1)
      local sParams = transformParams:select(2,paramIndex)
      paramIndex = paramIndex-1

      local selectedOutput = self.rotationOutput
      local selectedGradParams = gradParams:narrow(2,1,2):narrow(3,1,2)
      gradInputScaleparams:copy(torch.cmul(selectedOutput, selectedGradParams):sum(2):sum(3))

      gradParams:select(3,1):select(2,1):cmul(sParams)
      gradParams:select(3,2):select(2,1):cmul(sParams)
      gradParams:select(3,1):select(2,2):cmul(sParams)
      gradParams:select(3,2):select(2,2):cmul(sParams)

    end

    if self.useRotation then

      --local rParams = transformParams:select(2,paramIndex)

      local rotationDerivative = torch.zeros(batchSize, 3, 3):typeAs(transformParams)

      local gradInputRotationParams = self.gradInput:narrow(2,1,1)
      
      --torch.sin(rotationDerivative:select(3,1):select(2,1),-rParams)
      --torch.sin(rotationDerivative:select(3,2):select(2,2),-rParams)
      --torch.cos(rotationDerivative:select(3,1):select(2,2),rParams)
      --torch.cos(rotationDerivative:select(3,2):select(2,1),rParams):mul(-1)

      rotationDerivative = dR_by_dqi(transformParams,self.rotationOutput,1)	

      local selectedGradParams = gradParams:narrow(2,1,3):narrow(3,1,3)
      gradInputRotationParams:copy(torch.cmul(rotationDerivative,selectedGradParams):sum(2):sum(3))
      
      rotationDerivative = dR_by_dqi(transformParams,self.rotationOutput,2)	

      --local selectedGradParams = gradParams:narrow(2,1,3):narrow(3,1,3)
      gradInputRotationParams = self.gradInput:narrow(2,2,1)

      gradInputRotationParams:copy(torch.cmul(rotationDerivative,selectedGradParams):sum(2):sum(3))
      
      rotationDerivative = dR_by_dqi(transformParams,self.rotationOutput,3)
	
      --local selectedGradParams = gradParams:narrow(2,1,3):narrow(3,1,3)
      gradInputRotationParams = self.gradInput:narrow(2,3,1)
      gradInputRotationParams:copy(torch.cmul(rotationDerivative,selectedGradParams):sum(2):sum(3))

      rotationDerivative = dR_by_dqi(transformParams,self.rotationOutput,4)
      gradInputRotationParams = self.gradInput:narrow(2,4,1)
      gradInputRotationParams:copy(torch.cmul(rotationDerivative,selectedGradParams):sum(2):sum(3))
    end
  end

  if _tranformParams:nDimension()==1 then
    self.gradInput = self.gradInput:select(1,1)
  end
  return self.gradInput
end


