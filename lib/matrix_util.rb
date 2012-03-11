require 'matrix'

class Vector
  def []=(i,x)
    @elements[i] = x
  end
end

class Matrix
  def []=(i,j,x)
    @rows[i][j]=x
  end
end