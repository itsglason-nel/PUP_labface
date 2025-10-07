# Contributing to LabFace

Thank you for your interest in contributing to the LabFace Attendance System! This document provides guidelines for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Contributing Guidelines](#contributing-guidelines)
- [Pull Request Process](#pull-request-process)
- [Issue Reporting](#issue-reporting)
- [Development Standards](#development-standards)
- [Testing](#testing)
- [Documentation](#documentation)

## Code of Conduct

This project follows a code of conduct that we expect all contributors to adhere to:

- Be respectful and inclusive
- Use welcoming and inclusive language
- Be respectful of differing viewpoints and experiences
- Accept constructive criticism gracefully
- Focus on what is best for the community
- Show empathy towards other community members

## Getting Started

1. **Fork the Repository**: Click the "Fork" button on the GitHub repository page
2. **Clone Your Fork**: `git clone https://github.com/your-username/labface-attendance-system.git`
3. **Add Upstream Remote**: `git remote add upstream https://github.com/original-owner/labface-attendance-system.git`
4. **Create a Branch**: `git checkout -b feature/your-feature-name`

## Development Setup

### Prerequisites

- Docker and Docker Compose
- Node.js 18+ (for local development)
- Python 3.11+ (for ML service development)
- Git

### Local Development

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/your-username/labface-attendance-system.git
   cd labface-attendance-system
   ```

2. **Setup Environment**:
   ```bash
   cp env.example .env
   # Edit .env with your configuration
   ```

3. **Start Development Environment**:
   ```bash
   docker compose up --build
   ```

4. **Access Services**:
   - Frontend: http://localhost:3000
   - Backend: http://localhost:4000
   - ML Service: http://localhost:8000

### Backend Development

```bash
cd backend
npm install
npm run dev
```

### Frontend Development

```bash
cd frontend
npm install
npm run dev
```

### ML Service Development

```bash
cd ml-service
pip install -r requirements.txt
python main.py
```

## Contributing Guidelines

### Types of Contributions

We welcome various types of contributions:

- **Bug Fixes**: Fix issues and improve stability
- **Feature Development**: Add new features and functionality
- **Documentation**: Improve documentation and guides
- **Testing**: Add tests and improve test coverage
- **Performance**: Optimize performance and scalability
- **Security**: Improve security and compliance
- **UI/UX**: Enhance user interface and experience

### Development Workflow

1. **Create an Issue**: Before starting work, create an issue describing the problem or feature
2. **Assign Yourself**: Assign the issue to yourself
3. **Create a Branch**: Create a feature branch from `main`
4. **Make Changes**: Implement your changes
5. **Test Changes**: Ensure all tests pass
6. **Update Documentation**: Update relevant documentation
7. **Submit Pull Request**: Create a pull request with a clear description

### Branch Naming Convention

- `feature/description` - New features
- `fix/description` - Bug fixes
- `docs/description` - Documentation updates
- `test/description` - Testing improvements
- `refactor/description` - Code refactoring
- `security/description` - Security improvements

## Pull Request Process

### Before Submitting

1. **Run Tests**: Ensure all tests pass
   ```bash
   # Backend tests
   cd backend && npm test
   
   # Frontend tests
   cd frontend && npm test
   
   # ML service tests
   cd ml-service && python -m pytest
   ```

2. **Check Code Quality**: Run linting and formatting
   ```bash
   # Backend
   cd backend && npm run lint
   
   # Frontend
   cd frontend && npm run lint
   ```

3. **Update Documentation**: Update relevant documentation
4. **Test Manually**: Test your changes thoroughly

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Tests added/updated
- [ ] No breaking changes (or documented)

## Related Issues
Closes #issue_number
```

### Review Process

1. **Automated Checks**: CI/CD pipeline runs automatically
2. **Code Review**: At least one maintainer reviews the code
3. **Testing**: Changes are tested in staging environment
4. **Approval**: Maintainer approves the pull request
5. **Merge**: Changes are merged into main branch

## Issue Reporting

### Bug Reports

When reporting bugs, please include:

- **Description**: Clear description of the issue
- **Steps to Reproduce**: Detailed steps to reproduce the issue
- **Expected Behavior**: What should happen
- **Actual Behavior**: What actually happens
- **Environment**: OS, browser, version information
- **Screenshots**: If applicable
- **Logs**: Relevant error logs

### Feature Requests

When requesting features, please include:

- **Description**: Clear description of the feature
- **Use Case**: Why this feature is needed
- **Proposed Solution**: How you think it should work
- **Alternatives**: Other solutions you've considered
- **Additional Context**: Any other relevant information

## Development Standards

### Code Style

- **Backend**: Follow TypeScript/Node.js best practices
- **Frontend**: Follow React/Next.js best practices
- **ML Service**: Follow Python best practices
- **Database**: Follow SQL best practices

### Commit Messages

Use conventional commit format:

```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Testing
- `chore`: Maintenance

### File Organization

- Keep related files together
- Use descriptive file names
- Follow project structure
- Maintain consistent naming

## Testing

### Test Types

1. **Unit Tests**: Test individual components
2. **Integration Tests**: Test component interactions
3. **End-to-End Tests**: Test complete workflows
4. **Performance Tests**: Test system performance
5. **Security Tests**: Test security measures

### Running Tests

```bash
# Backend tests
cd backend && npm test

# Frontend tests
cd frontend && npm test

# ML service tests
cd ml-service && python -m pytest

# Integration tests
docker compose -f docker-compose.test.yml up --build
```

### Test Coverage

- Maintain at least 80% test coverage
- Write tests for new features
- Update tests when fixing bugs
- Include edge cases in tests

## Documentation

### Documentation Types

- **API Documentation**: Document all API endpoints
- **User Guides**: Step-by-step user instructions
- **Developer Guides**: Technical documentation
- **Security Guides**: Security best practices
- **Deployment Guides**: Deployment instructions

### Documentation Standards

- Use clear, concise language
- Include code examples
- Keep documentation up-to-date
- Use consistent formatting
- Include screenshots when helpful

## Security

### Security Guidelines

- Never commit secrets or credentials
- Use environment variables for configuration
- Follow security best practices
- Report security vulnerabilities responsibly
- Keep dependencies updated

### Security Reporting

For security vulnerabilities:

1. **DO NOT** create public issues
2. Email security@labface.edu
3. Include detailed information
4. Allow time for response
5. Follow responsible disclosure

## Performance

### Performance Guidelines

- Optimize database queries
- Use efficient algorithms
- Minimize resource usage
- Cache when appropriate
- Monitor performance metrics

### Performance Testing

- Test with realistic data volumes
- Monitor memory usage
- Check response times
- Test under load
- Optimize bottlenecks

## Release Process

### Version Numbering

We use [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Checklist

- [ ] All tests pass
- [ ] Documentation updated
- [ ] Changelog updated
- [ ] Version bumped
- [ ] Release notes prepared
- [ ] Security review completed

## Community

### Getting Help

- Check documentation first
- Search existing issues
- Ask questions in discussions
- Join our community chat
- Attend office hours

### Recognition

Contributors are recognized in:
- CONTRIBUTORS.md file
- Release notes
- Project documentation
- Community highlights

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Contact

- **Email**: contributors@labface.edu
- **Discord**: [LabFace Community](https://discord.gg/labface)
- **GitHub**: [LabFace Repository](https://github.com/labface/attendance-system)

---

Thank you for contributing to LabFace! 🎉
