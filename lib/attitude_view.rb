require 'gadget'
require 'gl'
require 'glu'
require 'XFileParser'

include Gl
include Glu

module Mv
  class AttitudeView
    include Gadget
    class Model
      class Material
        def initialize diffuseColor,ambientColor,shininess,specularColor,emissionColor
          @diffuseColor = diffuseColor
          @ambientColor = ambientColor
          @specularColor = specularColor
          @shininess = shininess
          @emissionColor = emissionColor
        end
        attr_reader :diffuseColor,:ambientColor,:specularColor,:shininess,:emissionColor
      end
      class Face
        def initialize vs,normal,material
          @vs = vs
          @normal = normal
          @material = material
        end
        attr_reader :material,:normal
        def n_vertices
          @vs.length
        end
        def vertex index
          @vs[index]
        end
      end
      def initialize filename
        reader = XFileParser::Reader.new(filename)
        model = reader.getModel
        @vertices = []
        model.getVertices.each{|v|
          @vertices.push [v[0],v[1],v[2]]
        }
        @materials = []
        model.getMaterials.each{|m|
          @materials.push Material.new(
            [m.faceColor[0],m.faceColor[1],m.faceColor[2],m.faceColor[3]],
            [m.faceColor[0],m.faceColor[1],m.faceColor[2],m.faceColor[3]],
            m.power,
            [m.specularColor[0],m.specularColor[1],m.specularColor[2],m.specularColor[3]],
            [m.emissiveColor[0],m.emissiveColor[1],m.emissiveColor[2],m.emissiveColor[3]]
          )
        }
        @tri_faces = []
        @quad_faces = []
        model.getFaces.each{|f|
          vs = []
          f.vertices.each{|i|
            vs.push @vertices[i]
          }
          normal = [-f.normal[0],-f.normal[1],-f.normal[2]]
          material = @materials[f.material]
          case f.vertices.length
          when 3
            @tri_faces.push Face.new(vs,normal,material)
          when 4
            @quad_faces.push Face.new(vs,normal,material)
          end
        }
      end
      attr_reader :vertices,:materials,:tri_faces,:quad_faces
    end
    def initialize args
      @frame = Control.new(args)
      attrib = [Wx::GL_RGBA,Wx::GL_DOUBLEBUFFER,Wx::GL_DEPTH_SIZE,24]
      @canvas = Wx::GLCanvas.new(@frame,-1,[0,0],@frame.size,Wx::FULL_REPAINT_ON_RESIZE,'GLCanvas',attrib)
      @canvas.evt_paint{@canvas.paint{render}}
      THE_APP.com(0).add_property_listener(:roll,:pitch){
        @canvas.refresh false,nil
      }
      @frame.evt_size{|evt|
        @canvas.size = evt.size
      }
      @model = Model.new("orca.x")
    end
    private
    def render
      com = THE_APP.com(0)
      roll = com[:roll]
      pitch = com[:pitch]
      altitude = 10#com[:altitude]

      @canvas.set_current
      sz = @canvas.get_size
      w = sz.get_width
      h = sz.get_height
      #culling
      glEnable(GL_CULL_FACE)
      glCullFace(GL_BACK)
      #clear
      glEnable(GL_DEPTH_TEST)
      glShadeModel(GL_SMOOTH)
      glClearColor(0.6,0.7,1.0,0)
      glClear(Gl::GL_COLOR_BUFFER_BIT | Gl::GL_DEPTH_BUFFER_BIT)
      #viewport
      glViewport(0, 0, w, h)
      glMatrixMode(GL_PROJECTION)
      glLoadIdentity()
      gluPerspective(30.0, w.to_f/h.to_f, 0.5, 500.0)
      #modelview
      glMatrixMode(GL_MODELVIEW)
      glLoadIdentity()
      gluLookAt(-2.0, 0.0, -altitude,
        0.0, 0.0, -altitude,
        0.0, 0.0, -1.0)
      #light
      glEnable(GL_LIGHT0)
      glLightfv(GL_LIGHT0, GL_POSITION, [-10,0,-10])
      glLightfv(GL_LIGHT0, GL_AMBIENT, [0.2,0.2,0.2,1.0])
      glLightfv(GL_LIGHT0, GL_DIFFUSE, [0.8,0.8,0.8,1.0])
      glLightfv(GL_LIGHT0, GL_SPECULAR, [0.5,0.5,0.5,1.0])
      glEnable(GL_LIGHTING)
      #aircraft
      glPushMatrix
      glTranslate(0,0,-altitude)
      glRotate(roll, 1.0, 0.0, 0.0)
      glRotate(pitch, 0.0, 1.0, 0.0)
      glBegin(GL_TRIANGLES)
      @model.tri_faces.each{|f|
        m = f.material
        glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, m.diffuseColor)
        glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, m.ambientColor)
        glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, m.specularColor)
        glMaterialf(GL_FRONT_AND_BACK, GL_SHININESS, m.shininess)
        glMaterialfv(GL_FRONT_AND_BACK, GL_EMISSION, m.emissionColor)
        glNormal3d(f.normal)
        3.times{|i|
          glVertex3dv(f.vertex(i))
        }
      }
      glEnd
      glBegin(GL_QUADS)
      @model.quad_faces.each{|f|
        m = f.material
        glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, m.diffuseColor)
        glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, m.ambientColor)
        glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, m.specularColor)
        glMaterialf(GL_FRONT_AND_BACK, GL_SHININESS, m.shininess)
        glMaterialfv(GL_FRONT_AND_BACK, GL_EMISSION, m.emissionColor)
        glNormal3dv(f.normal)
        4.times{|i|
          glVertex3dv(f.vertex(i))
        }
      }
      glEnd
      glPopMatrix
      #ground
      glPushMatrix
      groundColor = [0.60,0.40,0.30,1.0]
      glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, groundColor)
      glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, groundColor)
      glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, [0,0,0,1])
      glMaterialf(GL_FRONT_AND_BACK, GL_SHININESS, 0)
      glMaterialfv(GL_FRONT_AND_BACK, GL_EMISSION, [0,0,0,1])
      glBegin(GL_QUADS)
      glNormal3dv(0,0,-1)
      glVertex3d( 2000, 2000,0)
      glVertex3d(-2000, 2000,0)
      glVertex3d( 2000,-2000,0)
      glVertex3d(-2000,-2000,0)
      glEnd
      glPopMatrix
      #swap
      @canvas.swap_buffers
    end
  end
end
