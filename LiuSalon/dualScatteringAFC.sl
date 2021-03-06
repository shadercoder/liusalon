class dual_scattering_AFC(
    uniform color PrimaryHL_Color        = color(0.86, 0.67, 0.21);
    uniform float PrimaryHL_Intensity    = 0.1;
    uniform float PrimaryHL_LongituShift = -4.5;   //[-10, -5]
    uniform float PrimaryHL_LongituWidth = 0.7;    //[  5, 10]

    uniform color BacklitRim_Color          = color(0.89, 0.98, 0.35);
    uniform float BacklitRim_Intensity      = 0.05; 
    uniform float BacklitRim_LongituShift   = 1;   //-PrimaryHL_LongituShift/2
    uniform float BacklitRim_LongituWidth   = 2;   //PrimaryHL_LongituWidth/2
    uniform float BacklitRim_AzimuthalWidth = 30;

    uniform color SecondaryHL_Color        = color(0.78, 0.4, 0.86);
    uniform float SecondaryHL_Intensity    = 0.1;
    uniform float SecondaryHL_LongituShift = -2;   //-3*PrimaryHL_LongituShift/2
    uniform float SecondaryHL_LongituWidth = 1.4;  //2*PrimaryHL_LongituWidth
    
    uniform float Glints_Intensity = 0.2;          //limit 0.5
    uniform float Glints_AzimuthalShift = 35;      //random per strand[30, 40]
    uniform float Glints_AzimuthalWidth = 0.3;     //[0,1] eqv to frequency

    uniform color ForwardScattering_Color      = color(1,0,0);
    uniform float ForwardScattering_Intensity  = 0.1;
    
    uniform color BackScattering_Color         = color(0.9,1,0);
    uniform float BackScattering_Intensity     = 0.1;
    uniform float BackScattering_LongituShift  = -2;
    uniform float BackScattering_LongituWidth  = 0.5;
	
	uniform float hairs_that_cast_full_shadow = 15;//not sure??????
    
    )
{
    constant float hemi_f = 0;
    constant float hemi_b = 1;
    
    
    constant float M_PI_2 = PI * 0.5;
    constant float M_PI_4 = PI * 0.25;
    constant float M_1_PI = 1.0 / PI;
    constant float M_2_PI = 2.0 / PI;
    
    constant float segment = 0.1;
    constant float inv_segment = 1 / segment;
    
    constant float tableSize = ceil( PI / segment );
    
    constant float d_b = 0.7;//backward scattering density factor
    constant float d_f = 0.7;//forward scattering density factor
    constant color integrateFsOverFullSphere;
    
    
    //Defining the uniform parameters used in the pre-computation step
    uniform color a_f[];
    uniform color a_b[];
    uniform color alpha_f[];
    uniform color alpha_b[];
    uniform color beta_f[];
    uniform color beta_b[];
    
    uniform color A_b[];
    uniform color delta_b[];
    uniform color sigma_b[];

    //Defining the varying parameters which have different values for each shading point
    varying float hairs_in_front;
    varying color sigma_f_squared;
    varying color T_f;

   
    float g(float deviation, x;)
    {   //unit-integral zero-mean Gaussian distribution
       return exp( - x*x /( 2*deviation*deviation ) ) / ( deviation * sqrt(2*PI) );
    }
    
	float gvar(float variance, x;)
	{
		return exp( - x*x /( 2*variance ) ) / sqrt(2*PI*variance) ;
	}
	
	float M_R(float theta_h;){
		float alpha_ = radians(PrimaryHL_LongituShift);
        float beta_  = radians(PrimaryHL_LongituWidth);
		return g(beta_, theta_h - alpha_);
	}
	
	float M_TT(float theta_h;){
		float alpha_ = radians(BacklitRim_LongituShift);
        float beta_  = radians(BacklitRim_LongituWidth);
		return g(beta_, theta_h - alpha_);
	}
	
	float M_TRT(float theta_h;){
		float alpha_ = radians(SecondaryHL_LongituShift);
        float beta_  = radians(SecondaryHL_LongituWidth);
		return g(beta_, theta_h - alpha_);
	}
	
	color MG_R(float theta_h;){
		float alpha_ = radians(PrimaryHL_LongituShift);
        float beta_  = radians(PrimaryHL_LongituWidth);
		
		color result;
        result[0] = gvar(pow(beta_,2) + sigma_f_squared[0], theta_h - alpha_);
        result[1] = gvar(pow(beta_,2) + sigma_f_squared[1], theta_h - alpha_);
        result[2] = gvar(pow(beta_,2) + sigma_f_squared[2], theta_h - alpha_);
        
        return result;
	}
	
	color MG_TT(float theta_h;){
		float alpha_ = radians(BacklitRim_LongituShift);
        float beta_  = radians(BacklitRim_LongituWidth);
		
		color result;
        result[0] = gvar(pow(beta_,2) + sigma_f_squared[0], theta_h - alpha_);
        result[1] = gvar(pow(beta_,2) + sigma_f_squared[1], theta_h - alpha_);
        result[2] = gvar(pow(beta_,2) + sigma_f_squared[2], theta_h - alpha_);
        
        return result;
	}
	
	color MG_TRT(float theta_h;){
		float alpha_ = radians(SecondaryHL_LongituShift);
        float beta_  = radians(SecondaryHL_LongituWidth);
		
		color result;
        result[0] = gvar(pow(beta_,2) + sigma_f_squared[0], theta_h - alpha_);
        result[1] = gvar(pow(beta_,2) + sigma_f_squared[1], theta_h - alpha_);
        result[2] = gvar(pow(beta_,2) + sigma_f_squared[2], theta_h - alpha_);
        
        return result;
	}
    
	float N_R(float phi;){
		return cos(phi * 0.5);
	}
	
	float N_TT(float phi;){
		float gamma_TT = radians(BacklitRim_AzimuthalWidth);
        return g(gamma_TT, PI - phi);
	}
	
	float N_TRT(float phi;){
		float G_angle       = radians(Glints_AzimuthalShift);
		float gamma_G       = radians(Glints_AzimuthalWidth);

		float N_TRT_minus_G = cos(phi * 0.5);
		float N_G           = Glints_Intensity * g(gamma_G, G_angle - phi);
		return N_TRT_minus_G + N_G;
	}
	
	float NG_R(){
		return 2 * (sin(M_PI_2) - sin(M_PI_4)) * M_2_PI;//integrate cos(phi/2)
	}
	
	float NG_TT(){
		float result = 0.0;
		
		float gamma_TT = radians(BacklitRim_AzimuthalWidth);
		
		float phi;
		
		for(phi = M_PI_2; phi <= PI; phi += segment)
			result += g(gamma_TT, PI - phi);
		result *= segment;
		
		return result * M_2_PI;
	}
	
	float NG_TRT(){
		float result = 0.0;
		
		float G_angle       = radians(Glints_AzimuthalShift);
		float gamma_G       = radians(Glints_AzimuthalWidth);

		float phi;
		
		for(phi = M_PI_2; phi <= PI; phi += segment){        
			float N_TRT_minus_G = cos(phi * 0.5);
			float N_G           = Glints_Intensity * g(gamma_G, G_angle - phi);
			result += (N_TRT_minus_G + N_G);
		}
		result *= segment;
		
		return result * M_2_PI;
	}

    vector GlobalToLocal(vector gv, x, y, z;)
    {
        //transform global vector gv by matrix [LocalUnitX, LocalUnitY, LocalUnitZ]

        float x_ = gv[0] * x[0] + gv[1] * y[0] + gv[2] * z[0];
        float y_ = gv[0] * x[1] + gv[1] * y[1] + gv[2] * z[1];
        float z_ = gv[0] * x[2] + gv[1] * y[2] + gv[2] * z[2];

        return vector(x_, y_, z_);
    }

	color fs_R(float theta_h, phi;)
    {
        return PrimaryHL_Color * PrimaryHL_Intensity * M_R(theta_h) * N_R(phi);
    }
	
	color fs_TT(float theta_h, phi;)
    {
        return BacklitRim_Color * BacklitRim_Intensity * M_TT(theta_h) * N_TT(phi);
    }
	
	color fs_TRT(float theta_h, phi;)
    {
        return SecondaryHL_Color * SecondaryHL_Intensity * M_TRT(theta_h) * N_TRT(phi);
    }
	
    color fs(float theta, phi;)
    {
        float theta_h = theta * 0.5;
        return (fs_R(theta_h, phi) + fs_TT(theta_h, phi) + fs_TRT(theta_h, phi)) / pow(cos(theta), 2);
    }
 
    color integrateOverFullSphere()//integrate over the full sphere around the shading point
    {
        float theta, phi;
        color result = 0.0;

        for(phi = - PI; phi <= PI; phi += 0.1)
            for(theta = - M_PI_2; theta <= M_PI_2; theta += 0.1){
                result  += fs(theta, phi);
			}
        result = result * 0.1 * 0.1;

        return result;

    }

    color fs_normalized(float theta, phi;)
    {
        
        color f = fs(theta, phi);
        return color(f[0]/integrateFsOverFullSphere[0], f[1]/integrateFsOverFullSphere[1], f[2]/integrateFsOverFullSphere[2]);
    }
    
    
    color color_abs(color x){
        return color(abs(x[0]), abs(x[1]), abs(x[2]));
    }

    color color_pow(color x; float n;){
        return color(pow(x[0],n), pow(x[1],n), pow(x[2],n));
    }
    
    color interpolate_theta_i(color ary[]; float theta_i) {
        
      
        if (theta_i == - M_PI_2)
            return ary[0];
        else if (theta_i < M_PI_2)
            return ary[0] - (ary[1] - ary[0]) * (M_PI_2- theta_i) * inv_segment;
        else if (theta_i == M_PI_2)
            return ary[tableSize-1];
        else if (theta_i > M_PI_2)
            return ary[tableSize-1] + (ary[tableSize-1] - ary[tableSize-2]) * (theta_i - M_PI_2) * inv_segment;
        else {
            float offset = (theta_i - M_PI_2) * inv_segment;
            float low = floor(offset);
            float high = ceil(offset);
            if (low == high)
                return ary[low];
            else
                return ary[low] + (ary[high] - ary[low]) * (offset - low)/(high - low);
        }
    }
    
    float isHemisphere(float hemisphere, theta_i, phi_i, theta_o, phi_o;)
    {
        // map $phi_i$ from [-PI, PI] to [0, 2*PI]
        float phi_i_ = phi_i;
        if (phi_i_ >= 0)
            phi_i_ -= M_PI_2;
        else
            phi_i_ += 3*M_PI_2;

        float cos_theta_i = cos(theta_i);
        vector vi = (-sin(phi_i_)*cos_theta_i, cos(phi_i_)*cos_theta_i, sin(theta_i));
 
        // map $phi_o$ from [-PI, PI] to [0, 2*PI]
        float phi_o_ = phi_o;
        if (phi_o_ >= 0)
            phi_o_ -= M_PI_2;
        else
            phi_o_ += 3*M_PI_2;
        float cos_theta_o = cos(theta_o);
        vector vo = (-sin(phi_o_)*cos_theta_o, cos(phi_o_)*cos_theta_o, sin(theta_o));
 
        float IdotO = vi . vo;
        // need front hemisphere
        if (hemisphere == hemi_f) { 
            if (IdotO < 0)
                return 0;
            else
                return 1;
        }
        else {//hemisphere == hemi_b
            if (IdotO >= 0)
                return 0;
            else
                return 1;
        }
    }
    
    //pre-computing and tabulating the uniform variables in the Constructor
    void populate_a(float hemisphere; output uniform color a[];) 
    {
        float theta_i = - M_PI_2;
        float phi_o, theta_o, phi_i;

        float i;
		float segment_ = 1.0;
       
		//printf("start of populate_a\n");
        for (i = 0; i < tableSize; i += 1) {
			//printf("i=%f\n", i);
            color sum_phi_o = 0.0;

            //omega_o decompose to phi_o and theta_O
            for (phi_o = - PI; phi_o <= PI; phi_o += segment_) {
				//printf("phi_o=%f\n", phi_o);
                color sum_theta_o = 0.0;

                for (theta_o = - M_PI_2; theta_o <= M_PI_2; theta_o += segment_) {
					//printf("theta_o=%f\n", theta_o);
                    float theta = theta_i + theta_o;

                    color sum_phi_i = 0.0;
                    
                    for (phi_i = - PI; phi_i <= PI; phi_i += segment_) {
						//printf("phi_i=%f\n", phi_i);
                        if (isHemisphere(hemisphere, theta_i, phi_i, theta_o, phi_o) == 0) 
                            continue;
                        
                        float phi = abs(phi_o - phi_i);
                        if( phi > PI)
                            phi -= 2*PI;
                        phi = abs(phi);


                        color fcos = color_abs(fs_normalized(theta, phi)) * cos(theta_i);
						//printf("i=%f;sum_f=%f,%f,%f\n",i,fcos[0],fcos[1],fcos[2]);
						
                        sum_phi_i += fcos;
						
                    }

                    sum_phi_i *= segment_;
                    sum_theta_o += sum_phi_i;
                }
                sum_theta_o *= segment_;
                sum_phi_o += sum_theta_o;
            }
            sum_phi_o *= segment_;

            push( a, sum_phi_o * M_1_PI );
            theta_i += segment;
        }
    }
    
    color integrateOverHemisphere(float theta_i, hemisphere;)
    {

        float phi_o, theta_o, phi_i;

        color sum_phi_o = 0.0;

		float segment_ = 0.5;
		
       for (phi_o = - PI; phi_o <= PI; phi_o += segment_) {
 
            color sum_theta_o = 0.0;

            for (theta_o = - M_PI_2; theta_o <= M_PI_2; theta_o += segment_) {
                
                float theta_h = (theta_i + theta_o) * 0.5;
                color sum_phi_i = 0.0;

                for (phi_i = - PI; phi_i <= PI; phi_i += segment_) {
                    if (isHemisphere(hemisphere, theta_i, phi_i, theta_o, phi_o) == 0) 
                        continue;

                    float phi = abs(phi_o - phi_i);
                    if( phi > PI)
                        phi -= 2*PI;
                    phi = abs(phi); 

                    color f = fs_R(theta_h, phi) + fs_TT(theta_h, phi) + fs_TRT(theta_h, phi);

                    sum_phi_i  += f;
                }
                sum_phi_i  *= segment_;
                sum_theta_o += sum_phi_i;
            }
            sum_theta_o *= segment_;
            sum_phi_o += sum_theta_o;
        }
        sum_phi_o *= segment_;
 
        return sum_phi_o;
    }

    color integrateOverHemisphereWeighted(float theta_i, hemisphere, coef;){


        float coef_R, coef_TT, coef_TRT;
        if (coef == 0) {
            coef_R = radians(PrimaryHL_LongituShift);
            coef_TT = radians(BacklitRim_LongituShift);
            coef_TRT= radians(SecondaryHL_LongituShift);
        }
        else {
            coef_R = radians(PrimaryHL_LongituWidth);
            coef_TT = radians(BacklitRim_LongituWidth);
            coef_TRT = radians(SecondaryHL_LongituWidth);
        }
 
        float phi_o, theta_o, phi_i;


        
        color sum_phi_o = 0.0;
        float segment_ = 0.5;
		
        for (phi_o = - PI; phi_o <= PI; phi_o += segment_) {
 
            color sum_theta_o = 0.0;

            for (theta_o = - M_PI_2; theta_o <= M_PI_2; theta_o += segment_) {
                
                
                float theta_h = (theta_i + theta_o) * 0.5;
                

                color sum_phi_i = 0.0;

                for (phi_i = - PI; phi_i <= PI; phi_i += segment_) {
                    if (isHemisphere(hemisphere, theta_i, phi_i, theta_o, phi_o) == 0) 
                        continue;

                    float phi = abs(phi_o - phi_i);
                    if( phi > PI)
                        phi -= 2*PI;
                    phi = abs(phi); 

					color f = fs_R(  theta_h, phi) * coef_R 
					        + fs_TT( theta_h, phi) * coef_TT
							+ fs_TRT(theta_h, phi) * coef_TRT;
                    
                    sum_phi_i  += f;
                }
                sum_phi_i  *= segment_;
                sum_theta_o += sum_phi_i;
            }
            sum_theta_o *= segment_;
            sum_phi_o += sum_theta_o;
        }
        sum_phi_o *= segment_;
 
        return sum_phi_o;

    }

    void populate_alphabeta(float hemisphere, coef; output uniform color target[];)
    {
        float theta_i = - M_PI_2;
        float i;
        color denominator = 0.0;
        color numerator = 0.0;
 
        for (i = 0; i < tableSize; i += 1) {
              numerator = integrateOverHemisphereWeighted(theta_i, hemisphere, coef);
            denominator = integrateOverHemisphere(theta_i, hemisphere);
             
            push( target, numerator / denominator );
            theta_i += segment;
        }
    }

    void populate_A_b(output uniform color A[];)
    {
        float i;
 
        for (i = 0; i < tableSize; i += 1) {
            color af = a_f[i];
            color ab = a_b[i];

            color afPow2 = color_pow(af, 2);
            
            color Ab;
            Ab[0] = ab[0] * afPow2[0] / (1 - afPow2[0]) + pow(ab[0],3) * afPow2[0]/pow(1-afPow2[0], 2);
            Ab[1] = ab[1] * afPow2[1] / (1 - afPow2[1]) + pow(ab[1],3) * afPow2[1]/pow(1-afPow2[1], 2);
            Ab[2] = ab[2] * afPow2[2] / (1 - afPow2[2]) + pow(ab[2],3) * afPow2[2]/pow(1-afPow2[2], 2);
            
            push( A, Ab );
        }
    }

    void populate_delta_b(output uniform color delta[];) 
    {
        float i;
 
        for (i = 0; i < tableSize; i += 1) {
            color af = a_f[i];
            color ab = a_b[i];

            color alphaf = alpha_f[i];
            color alphab = alpha_b[i];

            color afPow2 = color_pow(af, 2);
            color abPow2 = color_pow(ab, 2);

            color deltab;
            
            deltab[0] = alphab[0] * (1 - 2*abPow2[0]/pow(1-afPow2[0],2)) 
                + alphaf[0] * ( 2*pow(1-afPow2[0],2)+ 4*afPow2[0]*abPow2[0] ) / pow(1-afPow2[0], 3);
            
            deltab[1] = alphab[1] * (1 - 2*abPow2[1]/pow(1-afPow2[1],2)) 
                + alphaf[1] * ( 2*pow(1-afPow2[1],2)+ 4*afPow2[1]*abPow2[1] ) / pow(1-afPow2[1], 3);
                
            deltab[2] = alphab[2] * (1 - 2*abPow2[2]/pow(1-afPow2[2],2)) 
                + alphaf[2] * ( 2*pow(1-afPow2[2],2)+ 4*afPow2[2]*abPow2[2] ) / pow(1-afPow2[2], 3);
                
            push( delta, deltab );
        }
    }

    void populate_sigma_b(output uniform color sigma[];)
    {
        float i;
 
        for (i = 0; i < tableSize; i += 1) {
            color af = a_f[i];
            color ab = a_b[i];
            
            color betaf = beta_f[i];
            color betab = beta_b[i];

            color betabPow2 = color_pow(betab, 2);
            color betafPow2 = color_pow(betaf, 2);
            color abPow3 = color_pow(ab,3);

            color sigmab;
            sigmab[0] = (1 + d_b * pow(af[0],2)) * (ab[0] + abPow3[0]) * sqrt(2*betafPow2[0] + betabPow2[0])
                                    / ( ab[0] + abPow3[0]*(2*betaf[0] + 3*betab[0]) );
                                    
            sigmab[1] = (1 + d_b * pow(af[1],2)) * (ab[1] + abPow3[1]) * sqrt(2*betafPow2[1] + betabPow2[1])
                                    / ( ab[1] + abPow3[1]*(2*betaf[1] + 3*betab[1]) );
                                    
            sigmab[2] = (1 + d_b * pow(af[2],2)) * (ab[2] + abPow3[2]) * sqrt(2*betafPow2[2] + betabPow2[2])
                                    / ( ab[2] + abPow3[2]*(2*betaf[2] + 3*betab[2]) );
                                    
            push( sigma, sigmab );
        }
    }

    public void construct()
    {   
		integrateFsOverFullSphere = integrateOverFullSphere();
		// color a1 = color(1,2,3);
		// color a2 = color(2,3,4);
		// color a3= a1*a2;
		
		// color a4 = 4.0;
		// printf("color%f,%f,%f\n", a3[0],a3[1],a3[2]);
		// printf("color%f,%f,%f\n", a4[0],a4[1],a4[2]);
		
		// vector aa1 = vector(1,2,3);
		// vector aa2 = vector(4,2,3);
		// float a5 = aa1.aa2;
		// printf("%f\n",a5);
		
		// color a6 = a1 + 1.0;
		// printf("color6%f,%f,%f\n", a6[0],a6[1],a6[2]);
        /*average forward/backward attenuation*/
		//printf("begin construct\n");
        reserve(a_f, tableSize);
		//printf("reserve a_f\n");
        
        populate_a(hemi_f, a_f);
		//printf("a_f\n");
		reserve(a_b, tableSize);
        populate_a(hemi_b, a_b);
		//printf("a_b\n");
        /*average forward/backward scattering shift*/
        reserve(alpha_f, tableSize);
        reserve(alpha_b, tableSize);
        populate_alphabeta(hemi_f, 0, alpha_f);
		//printf("alpha_f\n");
        populate_alphabeta(hemi_b, 0, alpha_b);
		//printf("alpha_b\n");

        /*average forward/backward scattering deviation/width*/
        reserve(beta_f, tableSize);
        reserve(beta_b, tableSize);
        populate_alphabeta(hemi_f, 1, beta_f);
		//printf("beta_f\n");
        populate_alphabeta(hemi_b, 1, beta_b);
		//printf("beta_b\n");
		
        /*average backscattering attenuation*/
        reserve(A_b, tableSize);
        populate_A_b(A_b);
		//printf("A_b\n");

        /*average longitudinal shift*/
        reserve(delta_b, tableSize);
        populate_delta_b(delta_b);
		//printf("delta_b\n");

        /*average backscattering deviation*/
        reserve(sigma_b, tableSize);
        populate_sigma_b(sigma_b);      
		//printf("sigma_b\n");
		
		// color integral = integrateOverFullSphere();
		// printf("integrate= %f,%f,%f \n", integral[0], integral[1], integral[2] );
		// float i;
		// for (i = 0; i < tableSize; i += 1) {
		    // //color aaa= a_f[i];
			// //color aaa= a_b[i];
			// //color aaa= alpha_f[i];
			// //color aaa= beta_f[i];
			// //color aaa= A_b[i];
			// //color aaa= delta_b[i];
			// color aaa= sigma_b[i];
			// printf("a_f=%f,%f,%f\n",aaa[0],aaa[1],aaa[2]);
		// }
    }
    
    public void surface(output color Ci, Oi;)
    {
        // Get unit vectors along local axis in globle coordinate system
        vector lx  =  normalize(dPdu);
        vector ly  =  normalize(   N);  //the shading normal
        vector lz  =  normalize(dPdv);  //hair tangent (from root to tip)

        //I is the incident ray dir(from eye to the shading point)
        vector   omega_o = GlobalToLocal( -normalize(I), lx, ly, lz ); 
        float      phi_o = atan(omega_o[1], omega_o[0]);
        float    theta_o = M_PI_2 - acos(omega_o[2]);
        float alpha_back = radians(BackScattering_LongituShift);
        float  beta_back_squared = pow(radians(BackScattering_LongituWidth),2);

        // get deep shadow map value
        float shadow_bias = 0.005;
        float shadow_blur = 0.002;
        float shadow_samples = 9;
        uniform string shadowmap_path = "";
        attribute("light:user:delight_shadowmap_name", shadowmap_path);
		
        float shadow_p = shadow(shadowmap_path, P, "bias", shadow_bias, "samples", shadow_samples, "blur", shadow_blur);
        
        illuminance(P) //P is the shading point position, a function of (u,v)
        {
            //L is light ray (from shading point to the light source)
            vector omega_i = GlobalToLocal( normalize(L), lx, ly, lz ); 
            float    phi_i = atan(omega_i[1], omega_i[0]);
            float    phi   = abs(phi_o - phi_i); //relative azimuth (within the normal plane)
			
			//clamp $phi$ to [-PI, PI]
            if ( phi > PI )
                phi -= 2 * PI;
            phi = abs(phi);

            float theta_i = M_PI_2 - acos(omega_i[2]);
            float theta   = theta_i + theta_o;
            float theta_h = theta * 0.5; //half longitudial angle (wrt the normal plane)

            //interpolate value from pre-computation
            color     Ab = interpolate_theta_i(    A_b, theta_i);
            color deltab = interpolate_theta_i(delta_b, theta_i);
            color sigmab = interpolate_theta_i(sigma_b, theta_i);
            
            color  betaf = interpolate_theta_i( beta_f, theta_i);
            color     af = interpolate_theta_i(    a_f, theta_i);

            // compute the amount of shadow from the deep shadow maps
            float shadowed = shadow_p;
            float illuminated = 1 - shadowed;

            //estimate the number of hairs in front of the shading point
            hairs_in_front = shadowed * hairs_that_cast_full_shadow;
            //use the number of hairs in front of the shading point to approximate sigma_f
            sigma_f_squared = hairs_in_front * color_pow(betaf,2);
            //use the number of hairs in front of the shading point to approximate T_f
            T_f = d_f * color_pow(af, hairs_in_front);

			//printf("Tf=%f,%f,%f\n",T_f[0],T_f[1],T_f[2]);
            //backscattering for direct and indirect lighting
            color f_direct_back;
				  f_direct_back[0] =  2 * Ab[0] * gvar(pow(sigmab[0],2) + beta_back_squared, theta_h - deltab[0] + alpha_back) / ( PI * pow(cos(theta_i), 2) );
				  f_direct_back[1] =  2 * Ab[1] * gvar(pow(sigmab[1],2) + beta_back_squared, theta_h - deltab[1] + alpha_back) / ( PI * pow(cos(theta_i), 2) );
				  f_direct_back[2] =  2 * Ab[2] * gvar(pow(sigmab[2],2) + beta_back_squared, theta_h - deltab[2] + alpha_back) / ( PI * pow(cos(theta_i), 2) );
									
                  f_direct_back = BackScattering_Color * BackScattering_Intensity * f_direct_back;

            color f_scatter_back;
			      f_scatter_back[0] = 2 * Ab[0] * gvar(pow(sigmab[0],2) + sigma_f_squared[0] + beta_back_squared, theta_h - deltab[0] + alpha_back) / ( PI * pow(cos(theta), 2) );
				  f_scatter_back[1] = 2 * Ab[1] * gvar(pow(sigmab[1],2) + sigma_f_squared[1] + beta_back_squared, theta_h - deltab[1] + alpha_back) / ( PI * pow(cos(theta), 2) );
				  f_scatter_back[2] = 2 * Ab[2] * gvar(pow(sigmab[2],2) + sigma_f_squared[2] + beta_back_squared, theta_h - deltab[2] + alpha_back) / ( PI * pow(cos(theta), 2) );
									
                  f_scatter_back = BackScattering_Color * BackScattering_Intensity * f_scatter_back;

            //single scattering for direct and indirect lighting
            color f_direct_s  =  fs(theta, phi);

            color f_scatter_s = MG_R(  theta_h) * NG_R(  ) 
                              + MG_TT( theta_h) * NG_TT( ) 
                              + MG_TRT(theta_h) * NG_TRT();
							  
                  f_scatter_s = ForwardScattering_Color * ForwardScattering_Intensity * f_scatter_s;

	
            color F_direct  = illuminated * ( f_direct_s + d_b * f_direct_back );
            color F_scatter = (T_f - illuminated) * d_f * ( f_scatter_s + PI * d_b * f_scatter_back);
			
			
	
            //combine the direct and indirect scattering components
            Ci  += (F_direct + F_scatter) * cos(theta_i);
        }

        Oi  = Os; //Os is the surface opacity
        Ci *= Oi;
    
    }
}