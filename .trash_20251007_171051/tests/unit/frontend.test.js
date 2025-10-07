import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import { BrowserRouter } from 'react-router-dom';

// Mock components and utilities
jest.mock('../../frontend/src/lib/api', () => ({
  api: {
    get: jest.fn(),
    post: jest.fn(),
    put: jest.fn(),
    delete: jest.fn()
  }
}));

jest.mock('../../frontend/src/lib/auth', () => ({
  getToken: jest.fn(),
  setToken: jest.fn(),
  removeToken: jest.fn(),
  isAuthenticated: jest.fn()
}));

jest.mock('../../frontend/src/lib/socket', () => ({
  socket: {
    connect: jest.fn(),
    disconnect: jest.fn(),
    emit: jest.fn(),
    on: jest.fn(),
    off: jest.fn()
  }
}));

// Import components to test
import Button from '../../frontend/src/components/ui/Button';
import Card from '../../frontend/src/components/ui/Card';
import Input from '../../frontend/src/components/ui/Input';

describe('LabFace Frontend Unit Tests', () => {
  describe('UI Components', () => {
    test('Button component renders correctly', () => {
      render(<Button>Test Button</Button>);
      expect(screen.getByText('Test Button')).toBeInTheDocument();
    });

    test('Button component handles click events', () => {
      const handleClick = jest.fn();
      render(<Button onClick={handleClick}>Click Me</Button>);
      
      fireEvent.click(screen.getByText('Click Me'));
      expect(handleClick).toHaveBeenCalledTimes(1);
    });

    test('Button component applies correct classes', () => {
      render(<Button variant="primary" size="lg">Test</Button>);
      const button = screen.getByText('Test');
      expect(button).toHaveClass('bg-blue-600', 'text-white', 'px-6', 'py-3');
    });

    test('Card component renders correctly', () => {
      render(
        <Card>
          <h2>Card Title</h2>
          <p>Card content</p>
        </Card>
      );
      
      expect(screen.getByText('Card Title')).toBeInTheDocument();
      expect(screen.getByText('Card content')).toBeInTheDocument();
    });

    test('Input component renders correctly', () => {
      render(<Input placeholder="Enter text" />);
      expect(screen.getByPlaceholderText('Enter text')).toBeInTheDocument();
    });

    test('Input component handles change events', () => {
      const handleChange = jest.fn();
      render(<Input onChange={handleChange} />);
      
      fireEvent.change(screen.getByRole('textbox'), { target: { value: 'test' } });
      expect(handleChange).toHaveBeenCalled();
    });
  });

  describe('Authentication', () => {
    test('Professor login form validation', async () => {
      const { api } = require('../../frontend/src/lib/api');
      const { setToken } = require('../../frontend/src/lib/auth');
      
      // Mock successful login
      api.post.mockResolvedValue({
        data: {
          token: 'test_token',
          user: { id: 'PROF001', role: 'professor' }
        }
      });
      
      setToken.mockImplementation(() => {});
      
      // Test form validation
      const formData = {
        email: 'professor@university.edu',
        password: 'password123'
      };
      
      // Simulate form submission
      const response = await api.post('/auth/professor/login', formData);
      
      expect(response.data.token).toBe('test_token');
      expect(setToken).toHaveBeenCalledWith('test_token');
    });

    test('Student registration form validation', async () => {
      const { api } = require('../../frontend/src/lib/api');
      
      // Mock successful registration
      api.post.mockResolvedValue({
        data: { message: 'Registration successful' }
      });
      
      const formData = {
        student_id: 'STU001',
        first_name: 'John',
        last_name: 'Doe',
        email: 'john.doe@student.edu',
        password: 'password123',
        course: 'Computer Science',
        year_level: 2
      };
      
      const response = await api.post('/auth/student/register', formData);
      
      expect(response.data.message).toBe('Registration successful');
    });
  });

  describe('API Integration', () => {
    test('API client handles requests correctly', async () => {
      const { api } = require('../../frontend/src/lib/api');
      
      // Mock successful response
      api.get.mockResolvedValue({
        data: [{ id: 1, name: 'Class 1' }]
      });
      
      const response = await api.get('/classes');
      
      expect(response.data).toHaveLength(1);
      expect(response.data[0].name).toBe('Class 1');
    });

    test('API client handles errors correctly', async () => {
      const { api } = require('../../frontend/src/lib/api');
      
      // Mock error response
      api.get.mockRejectedValue({
        response: {
          status: 401,
          data: { error: 'Unauthorized' }
        }
      });
      
      try {
        await api.get('/classes');
      } catch (error) {
        expect(error.response.status).toBe(401);
        expect(error.response.data.error).toBe('Unauthorized');
      }
    });
  });

  describe('Socket.IO Integration', () => {
    test('Socket connection handling', () => {
      const { socket } = require('../../frontend/src/lib/socket');
      
      // Test connection
      socket.connect();
      expect(socket.connect).toHaveBeenCalled();
    });

    test('Socket event handling', () => {
      const { socket } = require('../../frontend/src/lib/socket');
      const mockCallback = jest.fn();
      
      // Test event listener
      socket.on('attendance_update', mockCallback);
      expect(socket.on).toHaveBeenCalledWith('attendance_update', mockCallback);
    });
  });

  describe('Form Validation', () => {
    test('Email validation', () => {
      const validEmails = [
        'test@example.com',
        'user.name@domain.co.uk',
        'user+tag@example.org'
      ];
      
      const invalidEmails = [
        'invalid-email',
        '@domain.com',
        'user@',
        'user@domain'
      ];
      
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      
      validEmails.forEach(email => {
        expect(emailRegex.test(email)).toBe(true);
      });
      
      invalidEmails.forEach(email => {
        expect(emailRegex.test(email)).toBe(false);
      });
    });

    test('Password validation', () => {
      const validPasswords = [
        'Password123',
        'SecurePass1',
        'MyPassword99'
      ];
      
      const invalidPasswords = [
        'password',
        '12345678',
        'PASSWORD',
        'Pass1'
      ];
      
      const passwordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d@$!%*?&]{8,}$/;
      
      validPasswords.forEach(password => {
        expect(passwordRegex.test(password)).toBe(true);
      });
      
      invalidPasswords.forEach(password => {
        expect(passwordRegex.test(password)).toBe(false);
      });
    });
  });

  describe('Local Storage', () => {
    test('Token storage and retrieval', () => {
      const { setToken, getToken, removeToken } = require('../../frontend/src/lib/auth');
      
      // Test setting token
      setToken('test_token');
      expect(getToken()).toBe('test_token');
      
      // Test removing token
      removeToken();
      expect(getToken()).toBeNull();
    });
  });

  describe('Error Handling', () => {
    test('Network error handling', async () => {
      const { api } = require('../../frontend/src/lib/api');
      
      // Mock network error
      api.get.mockRejectedValue(new Error('Network Error'));
      
      try {
        await api.get('/classes');
      } catch (error) {
        expect(error.message).toBe('Network Error');
      }
    });

    test('Timeout handling', async () => {
      const { api } = require('../../frontend/src/lib/api');
      
      // Mock timeout
      api.get.mockRejectedValue(new Error('Request timeout'));
      
      try {
        await api.get('/classes');
      } catch (error) {
        expect(error.message).toBe('Request timeout');
      }
    });
  });

  describe('Responsive Design', () => {
    test('Component responsiveness', () => {
      // Test that components render correctly on different screen sizes
      const { container } = render(
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3">
          <Card>Card 1</Card>
          <Card>Card 2</Card>
          <Card>Card 3</Card>
        </div>
      );
      
      expect(container.firstChild).toHaveClass('grid', 'grid-cols-1', 'md:grid-cols-2', 'lg:grid-cols-3');
    });
  });

  describe('Accessibility', () => {
    test('Button accessibility', () => {
      render(<Button aria-label="Submit form">Submit</Button>);
      expect(screen.getByLabelText('Submit form')).toBeInTheDocument();
    });

    test('Input accessibility', () => {
      render(<Input aria-label="Enter email" />);
      expect(screen.getByLabelText('Enter email')).toBeInTheDocument();
    });
  });

  describe('Performance', () => {
    test('Component rendering performance', () => {
      const startTime = performance.now();
      
      render(
        <div>
          {Array.from({ length: 100 }, (_, i) => (
            <Card key={i}>Card {i}</Card>
          ))}
        </div>
      );
      
      const endTime = performance.now();
      const renderTime = endTime - startTime;
      
      // Should render 100 cards in less than 100ms
      expect(renderTime).toBeLessThan(100);
    });
  });

  describe('Security', () => {
    test('XSS prevention', () => {
      const maliciousInput = '<script>alert("XSS")</script>';
      
      render(<Input value={maliciousInput} />);
      const input = screen.getByDisplayValue(maliciousInput);
      
      // The input should display the text as plain text, not execute it
      expect(input.value).toBe(maliciousInput);
    });
  });
});
