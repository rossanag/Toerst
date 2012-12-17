typedef struct{
	float2 vel;
	float2 f;
    float mass;
    //int2 texCoord;
    uint age;
    bool dead;
    float2 pos;
   // float4 dummy;
    
} Particle;

typedef struct {
    float2 pos;
    float4 color;
} ParticleVBO;

//#define COUNT_MULT 100.0f
#define COUNT_MULT 5.0f
//#define COUNT_MULT 5.0f
#define FORCE_CACHE_MULT 1000.f


void killParticle(global Particle * particle, global ParticleVBO * pos){
    particle->dead = true;
    pos->pos.x = -1;
    pos->pos.y = -1;
}


//######################################################
//  Particle Kernels
//######################################################


kernel void update(global Particle* particles,  global ParticleVBO* posBuffer, const float dt, const float damp, const float minSpeed, const float fadeInSpeed, const float fadeOutSpeed)
{
    size_t i = get_global_id(0);
    
    __global Particle *p = &particles[i];
    
    if(!p->dead){
        p->age ++;
        
        
//        if(p->age > 100){
        if(fadeOutSpeed > 0 && p->age > 100 && fast_length(p->vel) < 0.001 && posBuffer[i].color.a > 0){
            posBuffer[i].color.a -= fadeOutSpeed*p->mass;
            
            if(posBuffer[i].color.a < 0){
                killParticle(p,&posBuffer[i]);
            }
            
        } else if(posBuffer[i].color.a < 0.1*p->mass){
            posBuffer[i].color.a += fadeInSpeed*p->mass;
        }
        
        if(!p->dead){
            p->vel *= damp;
            
            float force = fast_length(p->f);
            if(force > minSpeed * p->mass){
                p->vel += p->f * p->mass;
            }
            
            if(fabs(p->vel.x) > 0 || fabs(p->vel.y) > 0){
                p->f = (float2)(0,0);
                
                float2 pos = posBuffer[i].pos + p->vel * dt;
                
                posBuffer[i].pos = pos;
                p->pos = pos;
                
                if(posBuffer[i].pos.x >= 1){
                    //            p->vel.x *= -1;
                    //                p->dead = true;
                    //              posBuffer[i].x -= 1;
                    killParticle(p, posBuffer+i);
                    //            posBuffer[i] = (float2)(0.5);
                }
                
                if(posBuffer[i].pos.y >= 1){
                    //    p->vel.y *= -1;
                    killParticle(p, posBuffer+i);
                }
                //            posBuffer[i] = (float2)(0.5);
                
                if(posBuffer[i].pos.x <= 0){
                    //            p->vel.x *= -1;
                    killParticle(p, posBuffer+i);
                }
                //            posBuffer[i] = (float2)(0.5);
                
                if(posBuffer[i].pos.y <= 0){
                    //            p->vel.y *= -1;
                    killParticle(p, posBuffer+i);
                }
                //          posBuffer[i] = (float2)(0.5);
                
            }
        }
    }
}


kernel void mouseForce(global Particle* particles,  const float2 mousePos, const float mouseForce, float mouseRadius){
    int id = get_global_id(0);
	global Particle *p = &particles[id];
    if(!p->dead){
        
        float2 diff = mousePos - p->pos;
        float dist = fast_length(diff);
        if(dist < mouseRadius){
            float invDistSQ = 1.0f / dist;
            diff *= mouseForce * invDistSQ;
            
            p->f +=  - diff;
        }
        
    }
}

kernel void mouseAdd(global Particle * particles, global ParticleVBO* posBuffer, const float2 addPos, const float mouseRadius, const int numAdd, const int numParticles ){
    if(numAdd == 0){
        return;
    }
    int id = get_global_id(0);
    int size = get_global_size(0);
    
    int fraction = numParticles / size;
    
    int added = 0;
    for(int i=id*fraction ; i<id*fraction+fraction ; i++){
        float fi = i;
        global Particle * p = &particles[i];
        if(p->dead){
            float2 offset = (float2)(sin(fi),cos(fi)) * mouseRadius*0.2 * sin(i*43.73214);
            
            p->dead = false;
            p->vel = (float2)(0);
            p->age = 0;
            posBuffer[i].pos = addPos + offset;
          //  posBuffer[i].color = (float4)(1,1,1,0);
            added ++;
        }
        
        if(numAdd == added)
            break;
    }
    
}

kernel void textureForce(global Particle* particles,  global ParticleVBO* posBuffer, read_only image2d_t image, const float force){
    int id = get_global_id(0);
    int width = get_image_width(image);
    
	global Particle *p = &particles[id];
    if(!p->dead){
        
        float2 texCoord = ((posBuffer[id].pos*(float2)(width,width)));
        float4 pixel = read_imagef(image, CLK_ADDRESS_CLAMP_TO_EDGE | CLK_FILTER_NEAREST, texCoord);
        
        float count = pixel.x;//-1.0/COUNT_MULT;
        if(count > 0.0){// && count <= 1.0){
            float2 dir = (float2)(pixel.y-0.5, pixel.z-0.5);
            
//            if(fast_length(dir) > 0.2){
                p->f += dir* (float2)(10.0 * force )*(float2)(p->mass-0.3);
//            }
        }
    }
}

kernel void forceTextureForce(global Particle* particles,  global ParticleVBO* posBuffer, global int * forceCache, const float force, const float forceMax, const int textureWidth){
    int i = get_global_id(0);
    global Particle *p = &particles[i];
    
    if(!p->dead){
        
        
        int x = convert_int((float)posBuffer[i].pos.x*textureWidth);
        int y = convert_int((float)posBuffer[i].pos.y*textureWidth);
        int texIndex = y*textureWidth+x;
        
        if(texIndex >= 0 && texIndex < textureWidth*textureWidth){
            
            
            float2 dir = (float2)(forceCache[texIndex*2]/FORCE_CACHE_MULT, forceCache[texIndex*2+1]/FORCE_CACHE_MULT);
            
            if(fast_length(dir) > forceMax){
                dir = fast_normalize(dir);
                dir *= forceMax;
            }
            p->f += dir * force;
        }
    }
}

kernel void sumParticles(global Particle * particles, global int * countCache, global int * forceCache, const int textureWidth){
   global Particle *p = &particles[get_global_id(0)];
    if(!p->dead){
        
        int i = get_global_id(0);
        
        int x = convert_int((float)p->pos.x*textureWidth);
        int y = convert_int((float)p->pos.y*textureWidth);
        int texIndex = y*textureWidth+x;
        
        if(texIndex >= 0 && texIndex < textureWidth*textureWidth){
            atomic_inc(&countCache[texIndex]);
            atomic_add(&forceCache[texIndex*2], p->vel.x*FORCE_CACHE_MULT);
            atomic_add(&forceCache[texIndex*2+1], p->vel.y*FORCE_CACHE_MULT);
        }
    }
}


/*
kernel void sumParticles2(global Particle * particles, global ParticleVBO* posBuffer, global int * countCache, global int * forceCache, const int numParticles, local int * localArea ){
    
    int textureWidth = get_global_size(0);
    int localSize = get_local_size(0);
    int lid = get_local_id(1) * get_local_size(0) + get_local_id(0);
    
    int gx = get_group_id(0)*localSize;
    int gy = get_group_id(1)*localSize;
    
    for(int i=lid;i<numParticles;i+= localSize*localSize){

        int x = convert_int((float)posBuffer[i].pos.x*textureWidth);
        int y = convert_int((float)posBuffer[i].pos.y*textureWidth);
        int texIndex = y*textureWidth+x;
        
        if(texIndex >= 0
           && texIndex < textureWidth*textureWidth
           && x >= gx
           && x < gx+localSize
           && y >= gy
           && y < gy+localSize){
            int lTexIndex = (y-gy)*localSize + (x-gx);
            
            localArea[lTexIndex] ++;
//            atomic_inc(&countCache[texIndex]);
//            
//            atomic_add(&forceCache[texIndex*2], p->vel.x*FORCE_CACHE_MULT);
//            atomic_add(&forceCache[texIndex*2+1], p->vel.y*FORCE_CACHE_MULT);
        }
    }
    
    barrier(CLK_LOCAL_MEM_FENCE);
    
}
*/
__constant sampler_t sampler = CLK_NORMALIZED_COORDS_FALSE | CLK_ADDRESS_CLAMP_TO_EDGE | CLK_FILTER_NEAREST;

__kernel void gaussian_blur(
                            __read_only image2d_t image,
                            __constant float * mask,
                            write_only image2d_t blurredImage,
                            __private int maskSize
                            ) {
    
    const int2 pos = {get_global_id(0), get_global_id(1)};
    float4 pixel = read_imagef(image, sampler, pos);
    
    // Collect neighbor values and multiply with gaussian
    float2 sum = 0.0f;
    // Calculate the mask size based on sigma (larger sigma, larger mask)
    for(int a = -maskSize; a < maskSize+1; a++) {
        for(int b = -maskSize; b < maskSize+1; b++) {
            sum += mask[a+maskSize+(b+maskSize)*(maskSize*2+1)]
            *read_imagef(image, sampler, pos + (int2)(a,b)).yz;
        }
    }
    
    write_imagef(blurredImage, pos, (float4)(pixel.x,sum.x,sum.y,1) );
//    blurredImage[pos.x+pos.y*get_global_size(0)] = sum;
}

__kernel void gaussianBlurSum(
                              global int * forceCache,
                              global int * forceCacheBlur,
                              const int textureWidth,
                              __constant float * mask,
                              __private int maskSize
                              ) {
    
    int idx = get_global_id(0);
    int idy = get_global_id(1);
    int global_id = idy*textureWidth + idx;
    
    // Collect neighbor values and multiply with Gaussian
    float2 sum = (float2)(0.0f,0.0f);
    for(int a = -maskSize; a < maskSize+1; a++) {
        for(int b = -maskSize; b < maskSize+1; b++) {
            
            if(idx+a > 0 && idy+b > 0 && idx+a < textureWidth && idx+b < textureWidth){
                int global_id_2 = (idy+b)*textureWidth + (idx+a);
                float2 force = (float2)(forceCache[global_id_2*2], forceCache[global_id_2*2+1]);
//                float2 force =  (float2)(1000,0);
                sum += mask[ a + maskSize+(b+maskSize)*(maskSize*2+1)]* force; //read_imagef(image, sampler, pos + (int2)(a,b)).x;
                
//                sum +=
            }
        }
    }
    
    //barrier(CLK_GLOBAL_MEM_FENCE);
    //forceCache[global_id*2]++;
    forceCacheBlur[global_id*2] = convert_int_sat(sum.x);
    forceCacheBlur[global_id*2+1] = convert_int(sum.y);;
    //blurredImage[pos.x+pos.y*get_global_size(0)] = sum;
}

//######################################################
//  Texture Kernels
//######################################################




kernel void resetCountCache(global int * countCache, global int * forceCache){
    countCache[get_global_id(0)] = 0;
    forceCache[get_global_id(0)*2] = 0;
    forceCache[get_global_id(0)*2+1] = 0;
}

kernel void updateForceTexture(write_only image2d_t image, global int * forceCache){
    int idx = get_global_id(0);
    int idy = get_global_id(1);
    int global_id = idy*get_image_width(image) + idx;
    
    int2 coords = (int2)(idx, idy);
    float2 force = (float2)(forceCache[global_id*2]/FORCE_CACHE_MULT, forceCache[global_id*2+1]/FORCE_CACHE_MULT);
    
    
    float4 color = (float4)(0,0,0,1);
    color += (float4)(1,0,0,0)*max(0.f , force.x*0.5f);
    color -= (float4)(0,0,1,0)*min(0.f , force.x*0.5f);
    color += (float4)(1,1,0,0)*max(0.f , force.y*0.5f);
    color -= (float4)(0,1,0,0)*min(0.f , force.y*0.5f);
    
    write_imagef(image, coords, color);
    
}

kernel void updateTexture(write_only image2d_t image, global ParticleVBO* posBuffer, const int numParticles, local int * particleCount, global int * countCache){
    int idx = get_global_id(0);
    int idy = get_global_id(1);
    int local_size = (int)get_local_size(0)*(int)get_local_size(1);
    int tid = get_local_id(1) * get_local_size(0) + get_local_id(0);
    
    
    int lidx =  get_local_id(0);
    int lidy =  get_local_id(1);
    
    int width = get_image_width(image);
    
    int groupx = get_group_id(0)*get_local_size(0);
    int groupy = get_group_id(1)*get_local_size(1);
    
    int global_id = idy*width + idx;
    
    
    //------
    
    
    particleCount[tid] = countCache[global_id];
    
    
    //--------
    barrier(CLK_LOCAL_MEM_FENCE);
    //--------
    
    
    
    uchar count = particleCount[tid];
    int diff[4];
    
    float2 dir = (float2)(0.,0.);
    int minDiff = 10;
    
    diff[0] = 0;
    if(lidx != 0){
        diff[0] = count - particleCount[tid-1];
    } else if(idx > 0) {
        diff[0] = count - convert_uchar_sat(countCache[global_id-1]);
    }
    
    diff[1] = 0;
    if(lidx != get_local_size(0)-1){
        diff[1] = count - particleCount[tid+1];
    } else if(idx < width-1){
        diff[1] = count - convert_uchar_sat(countCache[global_id+1]);
    }
    
    diff[2] = 0;
    if(lidy != 0){
        diff[2] = count - particleCount[tid-get_local_size(0)];
    } else if(global_id-width > 0){
        diff[2] = count - convert_uchar_sat(countCache[global_id-width]);
    }
    
    diff[3] = 0;
    if(lidy != get_local_size(1)-1){
        diff[3] = count - particleCount[tid+get_local_size(0)];
    } else  if(idy < width-1){
        diff[3] = count - convert_uchar_sat(countCache[global_id+width]);
    }

    
    
    int num = 0;
    int _diff = diff[0];
    for(int i=1;i<4;i++){
        if(diff[i] > diff[num]){
            _diff = diff[i];
            num = i;
        }
    }
    
    
    if(_diff > minDiff){
        switch(num){
            case 0:
                dir = (float2)(-0.1*_diff,0);
                break;
            case 1:
                dir += (float2)(0.1*_diff,0);
                break;
            case 2:
                dir += (float2)(0,-0.1*_diff);
                break;
            case 3:
                dir += (float2)(0,0.1*_diff);
                break;
            default:
                break;
        }
    }
    

    
    /* if(idx == 0 || idx == 1 || idx == width-1)
     dir = (float2)(0,0);
     */
    
    int2 coords = (int2)(get_global_id(0), get_global_id(1));
    
    dir *= 0.05;
    
    float countColor = clamp((convert_float(particleCount[tid])/COUNT_MULT),0.0f,1.0f);
    float4 color = (float4)(countColor,dir.x+0.5,dir.y+0.5,1);
    if(dir.x > 0.5 || dir.x < -0.5 ){
        color = (float4)(0,0,1,1);
    }
    if( dir.y > 0.5 || dir.y < -0.5 ){
        color = (float4)(0,1,0,1);
    }
    if((particleCount[tid]/COUNT_MULT) > 1.0){
        color = (float4)(1,1,1,1);
    }
    //    float4 color = (float4)(clamp((convert_float(particleCount[tid])/10.0f),0.0f,1.0f),0,0,1);
    // float4 color = (float4)(1,0,0,1);
    write_imagef(image, coords, color);
    
    //barrier(CLK_GLOBAL_MEM_FENCE);
    
    //--------
    //   countCache[global_id] = 0;
    //--------
    
}

