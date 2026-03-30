/**
 * Response Formatting Utilities
 * Standardized API response formatting
 */

/**
 * Success response format
 * @param {Object} res - Express response object
 * @param {any} data - Response data
 * @param {string} [message='Success'] - Success message
 * @param {number} [statusCode=200] - HTTP status code
 * @returns {Object} Response object
 */
function successResponse(res, data, message = 'Success', statusCode = 200) {
  const response = {
    success: true,
    message,
    data,
    timestamp: new Date().toISOString(),
  };
  
  return res.status(statusCode).json(response);
}

/**
 * Error response format
 * @param {Object} res - Express response object
 * @param {string} message - Error message
 * @param {number} [statusCode=500] - HTTP status code
 * @param {any} [details=null] - Error details
 * @returns {Object} Response object
 */
function errorResponse(res, message, statusCode = 500, details = null) {
  const response = {
    success: false,
    message,
    timestamp: new Date().toISOString(),
  };
  
  if (details) {
    response.details = details;
  }
  
  return res.status(statusCode).json(response);
}

/**
 * Paginated response format
 * @param {Object} res - Express response object
 * @param {any} data - Response data
 * @param {Object} pagination - Pagination metadata
 * @param {string} [message='Success'] - Success message
 * @returns {Object} Response object
 */
function paginatedResponse(res, data, pagination, message = 'Success') {
  const response = {
    success: true,
    message,
    data,
    pagination,
    timestamp: new Date().toISOString(),
  };
  
  return res.status(200).json(response);
}

/**
 * Validation error response
 * @param {Object} res - Express response object
 * @param {Array} errors - Validation errors
 * @returns {Object} Response object
 */
function validationErrorResponse(res, errors) {
  return errorResponse(res, 'Validation failed', 400, { errors });
}

/**
 * Not found response
 * @param {Object} res - Express response object
 * @param {string} [resource='Resource'] - Resource name
 * @returns {Object} Response object
 */
function notFoundResponse(res, resource = 'Resource') {
  return errorResponse(res, `${resource} not found`, 404);
}

/**
 * Unauthorized response
 * @param {Object} res - Express response object
 * @param {string} [message='Unauthorized'] - Error message
 * @returns {Object} Response object
 */
function unauthorizedResponse(res, message = 'Unauthorized') {
  return errorResponse(res, message, 401);
}

/**
 * Forbidden response
 * @param {Object} res - Express response object
 * @param {string} [message='Forbidden'] - Error message
 * @returns {Object} Response object
 */
function forbiddenResponse(res, message = 'Forbidden') {
  return errorResponse(res, message, 403);
}

/**
 * Created response
 * @param {Object} res - Express response object
 * @param {any} data - Created resource data
 * @param {string} [message='Created successfully'] - Success message
 * @returns {Object} Response object
 */
function createdResponse(res, data, message = 'Created successfully') {
  return successResponse(res, data, message, 201);
}

/**
 * Updated response
 * @param {Object} res - Express response object
 * @param {any} data - Updated resource data
 * @param {string} [message='Updated successfully'] - Success message
 * @returns {Object} Response object
 */
function updatedResponse(res, data, message = 'Updated successfully') {
  return successResponse(res, data, message, 200);
}

/**
 * Deleted response
 * @param {Object} res - Express response object
 * @param {string} [message='Deleted successfully'] - Success message
 * @returns {Object} Response object
 */
function deletedResponse(res, message = 'Deleted successfully') {
  return successResponse(res, null, message, 200);
}

/**
 * Calculate pagination metadata
 * @param {number} page - Current page
 * @param {number} limit - Items per page
 * @param {number} totalCount - Total number of items
 * @returns {Object} Pagination metadata
 */
function calculatePagination(page, limit, totalCount) {
  const totalPages = Math.ceil(totalCount / limit);
  const hasNext = page < totalPages;
  const hasPrev = page > 1;
  
  return {
    currentPage: page,
    itemsPerPage: limit,
    totalItems: totalCount,
    totalPages,
    hasNext,
    hasPrev,
    nextPage: hasNext ? page + 1 : null,
    prevPage: hasPrev ? page - 1 : null,
  };
}

module.exports = {
  successResponse,
  errorResponse,
  paginatedResponse,
  validationErrorResponse,
  notFoundResponse,
  unauthorizedResponse,
  forbiddenResponse,
  createdResponse,
  updatedResponse,
  deletedResponse,
  calculatePagination,
};