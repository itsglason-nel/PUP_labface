describe('LabFace Authentication', () => {
  beforeEach(() => {
    cy.visit('/');
  });

  describe('Professor Authentication', () => {
    it('should display professor login form', () => {
      cy.visit('/professor/login');
      cy.get('h1').should('contain', 'Professor Login');
      cy.get('input[type="email"]').should('be.visible');
      cy.get('input[type="password"]').should('be.visible');
      cy.get('button[type="submit"]').should('contain', 'Login');
    });

    it('should validate professor login form', () => {
      cy.visit('/professor/login');
      
      // Test empty form submission
      cy.get('button[type="submit"]').click();
      cy.get('.error').should('be.visible');
      
      // Test invalid email
      cy.get('input[type="email"]').type('invalid-email');
      cy.get('input[type="password"]').type('password');
      cy.get('button[type="submit"]').click();
      cy.get('.error').should('contain', 'Invalid email');
    });

    it('should login professor successfully', () => {
      cy.visit('/professor/login');
      
      // Mock successful login
      cy.intercept('POST', '/api/auth/professor/login', {
        statusCode: 200,
        body: {
          token: 'test_token',
          user: {
            id: 'PROF001',
            first_name: 'John',
            last_name: 'Doe',
            email: 'john.doe@university.edu',
            role: 'professor'
          }
        }
      }).as('professorLogin');
      
      cy.get('input[type="email"]').type('john.doe@university.edu');
      cy.get('input[type="password"]').type('password123');
      cy.get('button[type="submit"]').click();
      
      cy.wait('@professorLogin');
      cy.url().should('include', '/professor/dashboard');
    });

    it('should display professor registration form', () => {
      cy.visit('/professor/register');
      cy.get('h1').should('contain', 'Professor Registration');
      cy.get('input[name="professor_id"]').should('be.visible');
      cy.get('input[name="first_name"]').should('be.visible');
      cy.get('input[name="last_name"]').should('be.visible');
      cy.get('input[name="email"]').should('be.visible');
      cy.get('input[name="password"]').should('be.visible');
    });

    it('should register professor successfully', () => {
      cy.visit('/professor/register');
      
      // Mock successful registration
      cy.intercept('POST', '/api/auth/professor/register', {
        statusCode: 201,
        body: {
          message: 'Professor registered successfully'
        }
      }).as('professorRegister');
      
      cy.get('input[name="professor_id"]').type('PROF001');
      cy.get('input[name="first_name"]').type('John');
      cy.get('input[name="last_name"]').type('Doe');
      cy.get('input[name="email"]').type('john.doe@university.edu');
      cy.get('input[name="password"]').type('password123');
      cy.get('button[type="submit"]').click();
      
      cy.wait('@professorRegister');
      cy.get('.success').should('contain', 'Registration successful');
    });
  });

  describe('Student Authentication', () => {
    it('should display student login form', () => {
      cy.visit('/student/login');
      cy.get('h1').should('contain', 'Student Login');
      cy.get('input[type="email"]').should('be.visible');
      cy.get('input[type="password"]').should('be.visible');
      cy.get('button[type="submit"]').should('contain', 'Login');
    });

    it('should validate student login form', () => {
      cy.visit('/student/login');
      
      // Test empty form submission
      cy.get('button[type="submit"]').click();
      cy.get('.error').should('be.visible');
      
      // Test invalid email
      cy.get('input[type="email"]').type('invalid-email');
      cy.get('input[type="password"]').type('password');
      cy.get('button[type="submit"]').click();
      cy.get('.error').should('contain', 'Invalid email');
    });

    it('should login student successfully', () => {
      cy.visit('/student/login');
      
      // Mock successful login
      cy.intercept('POST', '/api/auth/student/login', {
        statusCode: 200,
        body: {
          token: 'test_token',
          user: {
            id: 'STU001',
            first_name: 'Jane',
            last_name: 'Smith',
            email: 'jane.smith@student.edu',
            role: 'student'
          }
        }
      }).as('studentLogin');
      
      cy.get('input[type="email"]').type('jane.smith@student.edu');
      cy.get('input[type="password"]').type('password123');
      cy.get('button[type="submit"]').click();
      
      cy.wait('@studentLogin');
      cy.url().should('include', '/student/dashboard');
    });

    it('should display student registration wizard', () => {
      cy.visit('/student/register');
      cy.get('h1').should('contain', 'Student Registration');
      
      // Check for step indicators
      cy.get('.step-indicator').should('be.visible');
      cy.get('.step-1').should('have.class', 'active');
    });

    it('should complete student registration wizard', () => {
      cy.visit('/student/register');
      
      // Step 1: Personal Information
      cy.get('input[name="student_id"]').type('STU001');
      cy.get('input[name="first_name"]').type('Jane');
      cy.get('input[name="last_name"]').type('Smith');
      cy.get('input[name="email"]').type('jane.smith@student.edu');
      cy.get('input[name="course"]').type('Computer Science');
      cy.get('select[name="year_level"]').select('2');
      cy.get('button[type="submit"]').click();
      
      // Step 2: Face Capture
      cy.get('.step-2').should('have.class', 'active');
      cy.get('button').contains('Capture Face').click();
      
      // Step 3: Review & Consent
      cy.get('.step-3').should('have.class', 'active');
      cy.get('input[name="consent"]').check();
      cy.get('input[name="password"]').type('password123');
      cy.get('button[type="submit"]').click();
      
      // Should redirect to dashboard
      cy.url().should('include', '/student/dashboard');
    });
  });

  describe('Authentication Errors', () => {
    it('should handle login errors', () => {
      cy.visit('/professor/login');
      
      // Mock login error
      cy.intercept('POST', '/api/auth/professor/login', {
        statusCode: 401,
        body: {
          error: 'Invalid credentials'
        }
      }).as('loginError');
      
      cy.get('input[type="email"]').type('john.doe@university.edu');
      cy.get('input[type="password"]').type('wrong_password');
      cy.get('button[type="submit"]').click();
      
      cy.wait('@loginError');
      cy.get('.error').should('contain', 'Invalid credentials');
    });

    it('should handle registration errors', () => {
      cy.visit('/professor/register');
      
      // Mock registration error
      cy.intercept('POST', '/api/auth/professor/register', {
        statusCode: 400,
        body: {
          error: 'Email already exists'
        }
      }).as('registerError');
      
      cy.get('input[name="professor_id"]').type('PROF001');
      cy.get('input[name="first_name"]').type('John');
      cy.get('input[name="last_name"]').type('Doe');
      cy.get('input[name="email"]').type('existing@university.edu');
      cy.get('input[name="password"]').type('password123');
      cy.get('button[type="submit"]').click();
      
      cy.wait('@registerError');
      cy.get('.error').should('contain', 'Email already exists');
    });
  });

  describe('Logout', () => {
    it('should logout professor', () => {
      // Login first
      cy.visit('/professor/login');
      cy.get('input[type="email"]').type('john.doe@university.edu');
      cy.get('input[type="password"]').type('password123');
      cy.get('button[type="submit"]').click();
      
      // Should be on dashboard
      cy.url().should('include', '/professor/dashboard');
      
      // Logout
      cy.get('button').contains('Logout').click();
      cy.url().should('include', '/professor/login');
    });

    it('should logout student', () => {
      // Login first
      cy.visit('/student/login');
      cy.get('input[type="email"]').type('jane.smith@student.edu');
      cy.get('input[type="password"]').type('password123');
      cy.get('button[type="submit"]').click();
      
      // Should be on dashboard
      cy.url().should('include', '/student/dashboard');
      
      // Logout
      cy.get('button').contains('Logout').click();
      cy.url().should('include', '/student/login');
    });
  });
});
